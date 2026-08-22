locals {
  turno_blue_zone_id = "fbfb7f66c16b12538c0216fd089be6a9"
}

# blocks other CAs from issuing certificates for the domain
resource "cloudflare_dns_record" "turno-blue-caa" {
  zone_id = local.turno_blue_zone_id
  name    = "@"
  type    = "CAA"
  ttl     = 14400

  data = {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
}
