{
  description = "My Infrastructure for Home and Cloud Services";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://racci.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
  };

  outputs = inputs@{ self, flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.devenv.flakeModule
    ];

    systems = [ "x86_64-linux" "aarch64-linux" ];

    perSystem = { system, pkgs, ... }: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfreePredicate = pkg: pkg.pname == "terraform";
        };
      };

      devenv.shells.default = {
        packages = with pkgs; [
          cocogitto
          nix
          git
          age
          sops
          ssh-to-age
        ];

        languages = {
          nix.enable = true;
          terraform = {
            enable = true;
            package = pkgs.terraform.withPlugins (p: with p; [
              tailscale
              cloudflare
              sops
              proxmox
              digitalocean
            ]);
          };
        };
      };
    };
  };
}
