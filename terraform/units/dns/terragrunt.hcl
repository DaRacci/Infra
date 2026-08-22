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
          name = "infra-dns"
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
        cloudflare = {
          source = "cloudflare/cloudflare"
        }
        external = {
          source = "hashicorp/external"
        }
      }
    }

    provider "cloudflare" {
      api_token = data.sops_file.secrets.data["CLOUDFLARE_API_TOKEN"]
    }
  EOT
}

inputs = {
  admin = "admin@racci.dev"
}
