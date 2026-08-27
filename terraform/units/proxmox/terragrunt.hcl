include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Regenerate containers.tf.json from containers.nix before every plan/apply
# so the config Terraform sees is never stale. The store path is printed;
# terraform_source-style copying isn't needed since we cat it into place via
# the devenv task for local use, and here we rely on the generated file being
# present in the unit dir.
terraform {
  before_hook "generate_containers" {
    commands = get_terraform_commands_that_need_vars()
    execute  = ["${get_repo_root()}/scripts/generate-containers.sh"]
  }
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    terraform {
      backend "remote" {
        organization = "racci"
        workspaces {
          name = "infra-proxmox"
        }
      }
    }
  EOT
}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    terraform {
      required_providers {
        sops = {
          source = "carlpett/sops"
        }
        proxmox = {
          source = "bpg/proxmox"
        }
      }
    }

    provider "proxmox" {
      endpoint  = "https://pve.racci.dev/"
      api_token = "$${data.sops_file.secrets.data["PROXMOX.TOKEN_ID"]}=$${data.sops_file.secrets.data["PROXMOX.SECRET"]}"
      insecure  = false

      ssh {
        agent = true
      }
    }
  EOT
}
