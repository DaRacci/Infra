# Renders containers.nix into Terraform JSON.
# Called by the devenv task `tf:generate-containers` and by the terragrunt
# before_hook, so plans/applies always see fresh config.
{
  lib,
  writeText,
  jq,
  runCommand,
}:
let
  containers = import ./containers.nix { inherit lib; };

  # The provider schema uses camelCase block names for these two lists;
  # everything else in containers.nix is already snake_case matching HCL.
  renderMountPoint = map (
    {
      volume,
      path,
      size ? null,
      backup ? true,
      read_only ? false,
      mount_options ? null,
      acl ? false,
    }:
    {
      inherit volume path backup read_only acl mount_options;
      size = if size == null then null else toString size;
    }
  );

  renderPassthrough = map (
    {
      uid,
      gid,
      mode,
      path,
    }:
    {
      inherit uid gid mode path;
    }
  );

  renderContainer =
    _: cfg:
    cfg
    // {
      mount_point = renderMountPoint cfg.mount_point;
      device_passthrough = renderPassthrough cfg.device_passthrough;
    };

  raw = writeText "containers.tf.json" (
    builtins.toJSON {
      resource.proxmox_virtual_environment_container = lib.mapAttrs renderContainer containers;

      moved =
        let
          names = lib.attrNames containers;
        in
        map (name: {
          from = "proxmox_virtual_environment_container.containers[\"${name}\"]";
          to = "proxmox_virtual_environment_container.${name}";
        }) names;

      locals = {
        all_containers = lib.attrValues (
          lib.mapAttrs (name: _: "\${proxmox_virtual_environment_container.${name}}") containers
        );
      };
    }
  );
in
# Pretty-print with stable 2-space indent so the committed file diffs cleanly.
runCommand "containers.tf.json" { } ''
  ${jq}/bin/jq . < "${raw}" > $out
''
