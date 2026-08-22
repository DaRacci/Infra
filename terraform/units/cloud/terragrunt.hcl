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
          name = "infra-cloud"
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
        digitalocean = {
          source = "digitalocean/digitalocean"
        }
      }
    }

    locals {
      permissive_ips = split(",", data.sops_file.secrets.data.IPS)
    }

    provider "digitalocean" {
      token = data.sops_file.secrets.data["DIGITALOCEAN_API_TOKEN"]
    }
  EOT
}
