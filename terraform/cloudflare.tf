locals {
  # For each github page, create a CNAME alias to daracci.github.io
  github_pages = [
    "minix",
    "terix",
    "minix-conventions"
  ]

  digitalocean_ns = [
    "ns1",
    "ns2",
    "ns3"
  ]

  protonmail_verification = "protonmail-verification=540667c4f6981c58787105d33fb0a156c14b9ebb"
  dkim_value              = "dyj3dpfllc7brvxpnwdjzmk2is3mfjk2merbjrwns2siher4p64ra"
  dkim_keys = [
    "protonmail",
    "protonmail2",
    "protonmail3"
  ]
}

data "cloudflare_zone" "racci-dev" {
  name = "racci.dev"
}

# blocks other CAs from issuing certificates for the domain
resource "cloudflare_record" "racci-dev-caa" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "@"
  type    = "CAA"

  data {
    flags = "0"
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

#region Cloud Servers
resource "cloudflare_record" "digitalocean_nameservers" {
  for_each = { for key in local.digitalocean_ns : key => "${key}.digitalocean.com" }

  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "cloud"
  content = each.value
  type    = "NS"
  proxied = false
}

resource "cloudflare_record" "nextcloud" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "nextcloud"
  content = "chomp.cloud.racci.dev"
  type    = "CNAME"
  proxied = false
}

resource "cloudflare_record" "repo" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "repo"
  content = "149.28.95.114"
  type    = "A"
  proxied = false
}
#endregion

#region ProtonMail Records
resource "cloudflare_record" "verification" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "@"
  content = local.protonmail_verification
  type    = "TXT"
}

resource "cloudflare_record" "spf" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "@"
  content = "v=spf1 include:_spf.protonmail.ch mx -all"
  type    = "TXT"
}

resource "cloudflare_record" "dmarc" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "_dmarc"
  content = "v=DMARC1; p=reject; rua=mailto:${local.admin};"
  type    = "TXT"
}

resource "cloudflare_record" "dkim" {
  for_each = { for key in local.dkim_keys : key => key }

  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "${each.key}._domainkey"
  content = "${each.key}.domainkey.${local.dkim_value}.domains.proton.ch"
  type    = "CNAME"
  proxied = false
}

resource "cloudflare_record" "MX" {
  for_each = {
    "mail.protonmail.ch"    = 10
    "mailsec.protonmail.ch" = 20
  }

  zone_id  = data.cloudflare_zone.racci-dev.id
  name     = "@"
  content  = each.key
  type     = "MX"
  priority = each.value
  proxied  = false
}
#endregion

#region GitHub Pages Records
resource "cloudflare_record" "racci-dev-github-pages-challenge-TXT" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "_github-pages-challenge-daracci"
  content = "019f67c7bb1464952df9634b97f6fe"
  type    = "TXT"
}

resource "cloudflare_record" "racci-dev-github-pages" {
  for_each = { for page in local.github_pages : page => page }

  zone_id = data.cloudflare_zone.racci-dev.id
  name    = each.value
  content = "daracci.github.io"
  type    = "CNAME"
  proxied = false
}
#endregion

#region Gradle Verifications
resource "cloudflare_record" "gradle_slimjar_verification" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "slimjar"
  content = "gradle-verification=H18QZ1H7PSUZJMWEVOUTYW7TAIBQJ"
  type    = "TXT"
}
#endregion
