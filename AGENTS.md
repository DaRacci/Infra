# AGENTS.md - NixOS Infrastructure Repository

## Build/Lint/Test Commands

- **Format check**: `nix fmt -- --ci` (runs treefmt: terraform fmt, statix, prettier, shellcheck)
- **Format fix**: `nix fmt`
- **Terraform validate (all units)**: `nix develop --impure --command terragrunt run --all validate` (run from `terraform/units/` dir)
- **Validate a single unit**: `nix develop --impure --command terragrunt validate` (run from a unit dir, e.g. `terraform/units/dns/`)
- **Plan a single unit**: `terragrunt plan` (from a unit dir)
- **Plan all units**: `terragrunt run --all plan` (from `terraform/units/`)
- **Enter devshell**: `nix develop --impure` (includes terraform with providers, sops, age, cocogitto, terragrunt)

## Code Style

- **Indent**: 2 spaces, LF line endings, UTF-8, trailing newline required
- **Nix**: Use `nixfmt` style (via treefmt), run `deadnix` and `statix` for linting
- **Terraform**: Use `terraform fmt` style. Units live in `terraform/units/`, each with its own state/workspace.
- **Terragrunt**: Each unit has its own `terragrunt.hcl`; shared config in `terraform/root.hcl`
- **Secrets**: Managed via SOPS - see `.sops.yaml` for encryption rules

## Git Hooks (via devenv)

Pre-commit hooks auto-run: `deadnix`, `statix`, `ripsecrets`, `typos`, `treefmt`

## Project Structure

- `flake.nix` - Devshell, formatting, git-hooks configuration
- `terraform/` - Infrastructure as code
  - `root.hcl` - Shared Terragrunt config (sops data reads, repo_root local)
  - `units/` - Per-provider units, each with its own HCP workspace/state:
    - `dns/` (cloudflare, workspace `infra-dns`)
    - `tailscale/` (workspace `infra-tailscale`)
    - `cloud/` (digitalocean, workspace `infra-cloud`)
    - `proxmox/` (workspace `infra-proxmox`)
  - `secrets.yaml`, `host-keys.yaml` - Shared SOPS-encrypted data
- `scripts/` - Utility scripts (Nushell, Bash)

## Notes

- Terraform providers bundled in devshell (tailscale, cloudflare, sops, proxmox, digitalocean, external)
- Always use `nix develop --impure` for terraform/terragrunt commands to get correct provider versions
- Each unit runs against its own HCP Terraform Cloud workspace (`remote` backend)
