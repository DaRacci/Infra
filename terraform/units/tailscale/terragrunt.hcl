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
          name = "infra-tailscale"
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
        tailscale = {
          source = "tailscale/tailscale"
        }
        external = {
          source = "hashicorp/external"
        }
      }
    }

    provider "tailscale" {
      api_key = data.sops_file.secrets.data["TAILSCALE_API_KEY"]
      tailnet = "racci.dev"
    }
  EOT
}
