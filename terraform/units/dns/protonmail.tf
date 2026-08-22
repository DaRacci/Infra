locals {
  domains = [
    {
      zone_id      = "fbfb7f66c16b12538c0216fd089be6a9"
      dkim_value   = "d2itlmuqmyb3qlx4mawuavgrqoygseizyey2jevxdqqbqwwo5n2lq"
      verification = "protonmail-verification=c851e43e7865c4290e43c0186bcce437fe3de6e6"
    },
    {
      zone_id      = "32cc2f58a0e6ba5d390f2219af9e83ed"
      dkim_value   = "dyj3dpfllc7brvxpnwdjzmk2is3mfjk2merbjrwns2siher4p64ra"
      verification = "protonmail-verification=540667c4f6981c58787105d33fb0a156c14b9ebb"
      dmarc_rua    = "mailto:3d6ae971001b4e958194b313d3a70e83@dmarc-reports.cloudflare.net"
    }
  ]

  protonmail_verification = "protonmail-verification=c851e43e7865c4290e43c0186bcce437fe3de6e6"
  dkim_value              = "d2itlmuqmyb3qlx4mawuavgrqoygseizyey2jevxdqqbqwwo5n2lq"
  dkim_keys               = ["protonmail", "protonmail2", "protonmail3"]
  mx_records = {
    "mail.protonmail.ch"    = 10
    "mailsec.protonmail.ch" = 20
  }
}

resource "cloudflare_dns_record" "verification" {
  for_each = { for key in local.domains : key.zone_id => key }

  zone_id = each.key
  name    = "@"
  content = each.value.verification
  type    = "TXT"
  ttl     = 14400
}

resource "cloudflare_dns_record" "spf" {
  for_each = { for key in local.domains : key.zone_id => key }

  zone_id = each.key
  name    = "@"
  content = "v=spf1 include:_spf.protonmail.ch mx -all"
  type    = "TXT"
  ttl     = 14400
}

resource "cloudflare_dns_record" "dmarc" {
  for_each = { for key in local.domains : key.zone_id => key }

  zone_id = each.key
  name    = "_dmarc"
  content = try(
    "v=DMARC1; p=reject; rua=${each.value.dmarc_rua};",
    "v=DMARC1; p=reject; rua=mailto:${var.admin};"
  )
  type = "TXT"
  ttl  = 14400
}

resource "cloudflare_dns_record" "dkim" {
  for_each = {
    for combo in flatten([
      for domain in local.domains : [
        for key in local.dkim_keys : {
          zone_id    = domain.zone_id
          dkim_value = domain.dkim_value
          key        = key
        }
      ]
    ]) : "${combo.zone_id}-${combo.key}" => combo
  }

  zone_id = each.value.zone_id
  name    = "${each.value.key}._domainkey"
  content = "${each.value.key}.domainkey.${each.value.dkim_value}.domains.proton.ch"
  type    = "CNAME"
  ttl     = 14400
  proxied = false
}

resource "cloudflare_dns_record" "MX" {
  for_each = {
    for combo in flatten([
      for domain in local.domains : [
        for key, value in local.mx_records : {
          zone_id  = domain.zone_id
          key      = key
          priority = value
        }
      ]
    ]) : "${combo.zone_id}-${combo.key}" => combo
  }


  zone_id  = each.value.zone_id
  name     = "@"
  content  = each.value.key
  type     = "MX"
  ttl      = 14400
  priority = each.value.priority
  proxied  = false
}
