locals {
  # For each github page, create a CNAME alias to daracci.github.io
  github_pages = []

  digitalocean_ns = [
    "ns1",
    "ns2",
    "ns3"
  ]

  racci_dev_zone_id = "32cc2f58a0e6ba5d390f2219af9e83ed"
  tunnel_id         = "8d42e9b2-3814-45ea-bbb5-9056c8f017e2"
}

data "external" "cloudflare_tunnels" {
  program = [
    "nix",
    "eval",
    "github:DaRacci/nix-config#nixosConfigurations.nixio.config.services.cloudflared.tunnels.${local.tunnel_id}.ingress",
    "--json",
    "--apply",
    "(x: builtins.attrNames x |> builtins.map (x: { name = x; value = x; }) |> builtins.listToAttrs)"
  ]
}

resource "cloudflare_dns_record" "tunnels" {
  for_each = { for tunnel in data.external.cloudflare_tunnels.result : tunnel => tunnel }

  zone_id = local.racci_dev_zone_id
  name    = each.value
  content = "${local.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# blocks other CAs from issuing certificates for the domain
resource "cloudflare_dns_record" "racci-dev-caa" {
  zone_id = local.racci_dev_zone_id
  name    = "@"
  type    = "CAA"
  ttl     = 14400

  data = {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

#region Cloud Servers
resource "cloudflare_dns_record" "digitalocean_nameservers" {
  for_each = { for key in local.digitalocean_ns : key => "${key}.digitalocean.com" }

  zone_id = local.racci_dev_zone_id
  name    = "cloud"
  content = each.value
  type    = "NS"
  ttl     = 14400
  proxied = false
}

resource "cloudflare_dns_record" "nextcloud" {
  zone_id = local.racci_dev_zone_id
  name    = "nextcloud"
  content = "chomp.cloud.racci.dev"
  type    = "CNAME"
  ttl     = 14400
  proxied = false
}
#endregion

#region GitHub Pages Records
resource "cloudflare_dns_record" "racci-dev-github-pages-challenge-TXT" {
  zone_id = local.racci_dev_zone_id
  name    = "_github-pages-challenge-daracci"
  content = "019f67c7bb1464952df9634b97f6fe"
  type    = "TXT"
  ttl     = 14400
}

resource "cloudflare_dns_record" "racci-dev-github-pages" {
  for_each = { for page in local.github_pages : page => page }

  zone_id = local.racci_dev_zone_id
  name    = each.value
  content = "daracci.github.io"
  type    = "CNAME"
  ttl     = 14400
  proxied = false
}
#endregion

#region Gradle Verifications
resource "cloudflare_dns_record" "gradle_slimjar_verification" {
  zone_id = local.racci_dev_zone_id
  name    = "slimjar"
  content = "gradle-verification=H18QZ1H7PSUZJMWEVOUTYW7TAIBQJ"
  type    = "TXT"
  ttl     = 14400
}
#endregion
