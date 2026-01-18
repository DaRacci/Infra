terraform {
  required_providers {
    sops = {
      source = "carlpett/sops"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    proxmox = {
      source = "bpg/proxmox"
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
  endpoint  = "https://pve.racci.dev/"
  api_token = "${data.sops_file.secrets.data["PROXMOX.TOKEN_ID"]}=${data.sops_file.secrets.data["PROXMOX.SECRET"]}"
  insecure  = false

  ssh {
    agent = true
  }
}

provider "tailscale" {
  api_key = data.sops_file.secrets.data["TAILSCALE_API_KEY"]
  tailnet = "racci.dev"
}

provider "digitalocean" {
  token = data.sops_file.secrets.data["DIGITALOCEAN_API_TOKEN"]
}
