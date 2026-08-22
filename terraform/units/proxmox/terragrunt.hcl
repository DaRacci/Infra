include "root" {
  path = find_in_parent_folders("root.hcl")
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
