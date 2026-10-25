# Proxmox Unit

Container infrastructure for Proxmox VE, managed via generated Terraform.

## How It Works

The Proxmox unit uses a **Nix -> JSON -> Terraform** pipeline to manage containers:

### Source: `containers.nix`

Single source of truth for all container configurations.
It defines CPU, memory, storage, mounts, and device passthrough settings for each container.

- **Inheritance model**: All containers inherit from `defaults`, then receive overrides merged on top
- **List handling**: `mount_point` and `device_passthrough` replace entirely
- **Legacy workaround**: Containers in `legacyContainers` have empty `template_file_id` to prevent forced recreation after provider migration

Example:

```nix
nixserv = container "nixserv" {
  cpu.cores = 8;
  memory.dedicated = 8192;
  mount_point = [
    {
      volume = "local-zfs";
      path = "/nix/store";
      size = "128G";
    }
  ];
};
```

### Generator: `generate.nix`

Renders `containers.nix` to Terraform JSON.
Runs during a devenv task or as terragrunt before_hook.
This is theory should prevent any commands from being run without the correct environment, but alas, there will probably be some edge cases where the environment is not set up correctly.

**Outputs**:

- `resource.proxmox_virtual_environment_container.*` – All containers as Terraform resources
- `moved.*` – State migration paths (handles provider schema changes without recreation)
- `locals.all_containers` – Array of container references for cross-unit dependencies

**Details**:

- Converts Nix attrs to snake_case HCL matching Proxmox provider schema
- Pretty-prints via `jq` for clean git diffs

### Generated: `containers.tf.json`

Terraform JSON file consumed by `proxmox.tf`.
Fully resolved and ready for use from terraform.

### Orchestration: `proxmox.tf`

Manages Proxmox API calls and post-creation provisioning:

- **`terraform_data.nixos_configurations`** – Builds NixOS images via `build-image-and-transfer.nu`, transfers to Proxmox host
- **`terraform_data.init_after_creation`** – Runs post-creation provisioning:
  - Transfers `init-host.sh` to Proxmox host
  - Transfers SSH private key for container
  - Executes init script on Proxmox host, which runs inside the container

This ensures containers are fully bootstrapped before Terraform considers them done.

## Details

### Template File IDs

- **New containers**: `template_file_id = "local:vztmpl/{name}.tar.xz"` (must exist in Proxmox)
- **Legacy containers**: Empty string to preserve state after provider migration
- Legacy list is hard-coded; new containers automatically get the dynamic template path

### Device Passthrough

GPU support via passthrough:

```nix
rocmPassthrough = [
  { uid = 0; gid = 26; mode = "0660"; path = "/dev/dri/renderD128"; }
  { uid = 0; gid = 303; mode = "0660"; path = "/dev/kfd"; }
];

nixai = container "nixai" {
  device_passthrough = rocmPassthrough;
  # ...
};
```

### Mount Points

Containers can mount ZFS volumes and bind-mount paths from the host:

```nix
mount_point = [
  # ZFS volume
  {
    volume = "fast:subvol-108-disk-0";
    path = "/var/lib/prometheus2";
    size = "32G";
    backup = true;
    mount_options = secureMountOptions;
  }
  # Bind mount
  {
    volume = "/run/bluez/bus.sock";
    path = "/run/host-bluez/bus.sock";
    backup = false;
    mount_options = [ "bind" "optional" "create=file" ];
  }
];
```

## Troubleshooting

**JSON out of sync**: Run `devenv task tf:generate-containers`.
