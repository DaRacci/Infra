terraform {
  required_providers {
    sops = {
      source = "carlpett/sops"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc04"
    }
    tailscale = {
      source = "tailscale/tailscale"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

data "sops_file" "secrets" {
  source_file = "secrets.yaml"
}

data "sops_file" "ssh_keys" {
  source_file = "host-keys.yaml"
}

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["CLOUDFLARE_API_TOKEN"]
}

provider "proxmox" {
  pm_api_url          = "https://pve.racci.dev/api2/json"
  pm_api_token_id     = data.sops_file.secrets.data["PROXMOX.TOKEN_ID"]
  pm_api_token_secret = data.sops_file.secrets.data["PROXMOX.SECRET"]
}

provider "tailscale" {
  api_key = data.sops_file.secrets.data["TAILSCALE_API_KEY"]
  tailnet = "racci.dev"
}

provider "digitalocean" {
  token = data.sops_file.secrets.data["DIGITALOCEAN_API_TOKEN"]
}
