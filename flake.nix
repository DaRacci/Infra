{
  description = "My Infrastructure for Home and Cloud Services";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.racci.dev/global"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "global:OKNSxDYKp8Q8Tr5/5Bc7CYVSfvdFQV0dMhpG0fOAG0k="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-root.url = "github:srid/flake-root";
    # Source of truth for the nix-config hosts; consumed by the proxmox
    # container generator so host details come from a locked input ref
    # instead of scripts fetching at plan time.
    nix-config.url = "github:DaRacci/nix-config";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          config,
          system,
          pkgs,
          lib,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfreePredicate = pkg: pkg.pname == "terraform";
            };
          };

          # Renders terraform/units/proxmox/containers.nix to Terraform JSON.
          # Consumed by `tf-generate-containers` (devenv task + terragrunt
          # before_hook). nix-config input is available here for future use,
          # e.g. deriving host attributes from the locked ref.
          packages.proxmoxContainersJson =
            let
              tfDir = ./terraform/units/proxmox;
            in
            pkgs.callPackage (tfDir + "/generate.nix") { };

          devenv.shells.default = {
            # Fixes https://github.com/cachix/devenv/issues/528
            containers = lib.mkForce { };

            packages = with pkgs; [
              cocogitto
              git
              age
              sops
              ssh-to-age
              openssh
              terragrunt
            ];

            scripts.tf-generate-containers.exec = ''
              nix build --no-link --print-out-paths ".#proxmoxContainersJson" \
                | xargs cat > "$DEVENV_ROOT/terraform/units/proxmox/containers.tf.json"
            '';

            tasks."tf:generate-containers" = {
              exec = "tf-generate-containers";
            };

            languages = {
              nix.enable = true;
              terraform = {
                enable = true;
                package = pkgs.terraform.withPlugins (
                  p: with p; [
                    tailscale_tailscale
                    cloudflare_cloudflare
                    carlpett_sops
                    bpg_proxmox
                    digitalocean_digitalocean
                    hashicorp_external
                  ]
                );
              };
            };

            git-hooks.hooks = {
              deadnix.enable = true;
              statix.enable = true;
              ripsecrets.enable = true;
              typos = {
                enable = true;
                settings = {
                  ignored-words = [
                    "blong"
                  ];
                  # SOPS-encrypted yaml is ciphertext; spellcheck is meaningless on it.
                  force-exclude = true;
                  exclude = [
                    "terraform/*.yaml"
                  ];
                };
              };
              treefmt = {
                enable = true;
                package = config.treefmt.build.wrapper;
              };
            };
          };

          treefmt.config = {
            inherit (config.flake-root) projectRootFile;

            programs = {
              terraform = {
                enable = true;
                inherit (config.devenv.shells.default.languages.terraform) package;
              };
              statix.enable = true;
              prettier.enable = true;
              shellcheck.enable = true;
            };

            settings.global.excludes = [
              ".envrc"
              "terraform/secrets.yaml"
              "terraform/host-keys.yaml"
              "terraform/.terraform.lock.hcl"
            ];
          };
        };
    };
}
