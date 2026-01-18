module "domains" {
  source = "./domains"
  providers = {
    cloudflare = cloudflare
  }

  admin = local.admin
}
