data "tailscale_device" "bling-bling-blong" {
  name = "bling-bling-blong.degu-beta.ts.net"
}

data "tailscale_device" "adguard" {
  name = "adguard.degu-beta.ts.net"
}

resource "tailscale_device_subnet_routes" "bling-bling-blong_routes" {
  device_id = data.tailscale_device.bling-bling-blong.id
  routes = [
    # Allow Use as Exit Node
    "0.0.0.0/0",
    "::/0",

    # Network Ranges
    "10.10.100.0/24",
    "10.10.120.0/24",
    "10.10.200.0/24",
    "192.168.1.0/24"
  ]
}

resource "tailscale_device_subnet_routes" "adguard_routes" {
  device_id = data.tailscale_device.adguard.id
  routes = [
    # Allow Use as Exit Node
    "0.0.0.0/0",
    "::/0",

    # Network Ranges
    "192.168.2.0/24"
  ]
}

resource "tailscale_dns_nameservers" "adguard_dns" {
  nameservers = data.tailscale_device.adguard.addresses
}

resource "tailscale_dns_preferences" "preferences" {
  magic_dns = true
}

resource "tailscale_dns_search_paths" "search_domains" {
  search_paths = ["localdomain"]
}

resource "tailscale_acl" "as_hujson" {
  acl = jsonencode({
    acls = [
      // Allow access to own devices.
      {
        action = "accept",
        src    = ["autogroup:member"],
        dst    = ["autogroup:self:*"],
      },

      // Comment this section out if you want to define specific restrictions.
      { "action" : "accept", "src" : ["*"], "dst" : ["*:*"] },
    ],

    nodeAttrs = [],
    tests     = [],
  })
}
