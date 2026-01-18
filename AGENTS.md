# AGENTS.md - NixOS Infrastructure Repository

## Build/Lint/Test Commands

- **Format check**: `nix fmt -- --ci` (runs treefmt: terraform fmt, statix, prettier, shellcheck)
- **Format fix**: `nix fmt`
- **Terraform validate**: `nix develop --impure --command terraform validate` (run from `terraform/` dir)
- **Terraform init**: `terraform -chdir=terraform init -backend=false -upgrade`
- **Enter devshell**: `nix develop --impure` (includes terraform with providers, sops, age, cocogitto)

## Code Style

- **Indent**: 2 spaces, LF line endings, UTF-8, trailing newline required
- **Nix**: Use `nixfmt` style (via treefmt), run `deadnix` and `statix` for linting
- **Terraform**: Use `terraform fmt` style, modules in `terraform/domains/`
- **Secrets**: Managed via SOPS - see `.sops.yaml` for encryption rules

## Git Hooks (via devenv)

Pre-commit hooks auto-run: `deadnix`, `statix`, `ripsecrets`, `typos`, `treefmt`

## Project Structure

- `flake.nix` - Devshell, formatting, git-hooks configuration
- `terraform/` - Infrastructure as code (Cloudflare, Tailscale, Proxmox, DigitalOcean)
- `scripts/` - Utility scripts (Nushell, Bash)

## Notes

- Terraform providers bundled in devshell (tailscale, cloudflare, sops, proxmox, digitalocean, external)
- Always use `nix develop --impure` for terraform commands to get correct provider versions
