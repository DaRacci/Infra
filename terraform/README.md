# Terraform Infrastructure

IAC managed via Terragrunt, with per-provider units.

## Units

Each unit manages its own Terraform workspace and state:

### [Proxmox](units/proxmox/README.md)

Container orchestration for Proxmox VE. Generated Nix -> JSON -> Terraform pipeline for defining and provisioning LXC containers.

- **Workspace**: `infra-proxmox`
- **Key files**: `containers.nix`, `containers.tf.json`, `proxmox.tf`

### DNS

DNS records via Cloudflare.

- **Workspace**: `infra-dns`

### Tailscale

Tailscale network configuration.

- **Workspace**: `infra-tailscale`

### Cloud

DigitalOcean resources.

- **Workspace**: `infra-cloud`

## Common Commands

**Format check**:

```bash
nix fmt -- --ci
```

**Format fix**:

```bash
nix fmt
```

**Validate all units**:

```bash
cd units
nix develop --impure --command terragrunt run --all validate
```

**Plan/apply a single unit**:

```bash
cd units/proxmox
nix develop --impure --command terragrunt plan
nix develop --impure --command terragrunt apply
```

**Enter devshell**:

```bash
nix develop --impure
```

## Structure

- `root.hcl`: Shared Terragrunt config.
- `units/`: Per-provider units, each with own HCP Terraform Cloud workspace and state
- `secrets.yaml`, `host-keys.yaml`: SOPS-encrypted data
