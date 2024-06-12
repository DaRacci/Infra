locals {
  admin = "admin@racci.dev"

  permissive_ips = split(",", data.sops_file.secrets.data.IPS)
}
