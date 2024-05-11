locals {
  # For each github page, create a CNAME alias to nix-community.github.io
  github_pages = [
    "minix",
    "minix-conventions"
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

#region

#endregion

#region ProtonMail Records
resource "cloudflare_record" "verification" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "@"
  value   = local.protonmail_verification
  type    = "TXT"
}

resource "cloudflare_record" "spf" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "@"
  value   = "v=spf1 include:_spf.protonmail.ch mx -all"
  type    = "TXT"
}

resource "cloudflare_record" "dmarc" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "_dmarc"
  value   = "v=DMARC1; p=reject; rua=mailto:${local.admin};"
  type    = "TXT"
}

resource "cloudflare_record" "dkim" {
  for_each = { for key in local.local.dkim_keys : key => {
    key   = key
    value = local.dkim_value
  } }

  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "protonmail${each.key}._domainkey"
  value   = "protonmail${each.key}.domainkey.${each.value}.domains.protonmail.ch"
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
  value    = each.key
  type     = "MX"
  priority = each.value
  proxied  = false
}
#endregion

#region GitHub Pages Records
resource "cloudflare_record" "racci-dev-github-pages-challenge-TXT" {
  zone_id = data.cloudflare_zone.racci-dev.id
  name    = "_github-pages-challenge-daracci"
  value   = "019f67c7bb1464952df9634b97f6fe"
  type    = "TXT"
}

resource "cloudflare_record" "racci-dev-github-pages" {
  for_each = { for page in local.github_pages : page => page }

  zone_id = data.cloudflare_zone.racci-dev.id
  name    = each.value
  value   = "daracci.github.io"
  type    = "CNAME"
  proxied = false
}
#endregion
