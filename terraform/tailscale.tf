data "tailscale_device" "bling-bling-blong" {
  name = "bling-bling-blong.degu-beta.ts.net"
}

data "tailscale_device" "adguard" {
  name = "adguard.degu-beta.ts.net"
}

resource "tailscale_device_subnet_routes" "bling-bling-blong_routes" {
  device_id = data.tailscale_device.bling-bling-blong.id
  routes = [
    "192.168.1.0/24",
    "192.168.3.0/24",
    "192.168.4.0/24",
    "192.168.5.0/24"
  ]
}

resource "tailscale_dns_nameservers" "adguard_dns" {
  nameservers = data.tailscale_device.adguard.addresses
}

resource "tailscale_dns_preferences" "preferences" {
  magic_dns = true
}

resource "tailscale_dns_search_paths" "search_domains" {
  search_paths = [ "localadmin" ]
}

resource "tailscale_acl" "as_hujson" {
  acl = jsonencode({
    groups = {
      "group:admin" = ["me@racci.dev"],
      "group:home"  = ["me@racci.dev", "kinderoftheanime@gmail.com"],
    },

    tagOwners = {
      "tag:server" : ["autogroup:admin"],
      "tag:management" : ["autogroup:admin"],
      "tag:gateway" : [],
      "tag:service" : ["group:home"],
    },

    acls = [
      // Allow access for own devices.
      {
        action = "accept",
        src    = ["autogroup:member"],
        dst    = ["autogroup:self:*"],
      },

      // Allow home access to services
      {
        action = "accept",
        src    = ["group:home"],
        dst    = ["tag:service:*"],
      },

      // Allow access to management consoles & such
      {
        action = "accept",
        src    = ["group:admin"],
        dst    = ["tag:management:*", "tag:server:*"],
      },

      // Allow Home or local access to local range
      // Also allow access to use Exit Nodes
      {
        action = "accept",
        src    = ["group:home", "192.168.1.0/24"],
        dst    = ["192.168.1.0/24:*", "autogroup:internet:*"],
      },

      {
        action = "accept",
        src    = ["tag:server"],
        dst = [
          "192.168.1.0/24:*",
          "192.168.2.0/24:*",
          "192.168.3.0/24:*",
          "192.168.4.0/24:*",
          "192.168.5.0/24:*",
        ],
      },

      // Comment this section out if you want to define specific restrictions.
      // {"action": "accept", "src": ["*"], "dst": ["*:*"]},
    ],

    nodeAttrs = [
      {
        // Funnel policy, which lets tailnet members control Funnel
        // for their own devices.
        // Learn more at https://tailscale.com/kb/1223/tailscale-funnel/
        target = ["autogroup:member"],
        attr   = ["funnel"],
      },
      {
        target = ["*"],
        app    = { "tailscale.com/app-connectors" : [] }
      },
    ],

    tests = [

    ],
  })
}
