locals {
  bling-bling-blong = [for device in data.tailscale_devices.devices.devices : device if device.name == "bling-bling-blong.degu-beta.ts.net"][0]
  nixio             = [for device in data.tailscale_devices.devices.devices : device if device.name == "nixio.degu-beta.ts.net"][0]
}

data "external" "device_roles" {
  program = [
    "nix",
    "eval",
    "--json",
    "github:DaRacci/nix-config#nixosConfigurations.nixio.options.host.device.role.type.functor.payload.values",
    "--apply",
    "(roles: roles |> builtins.map (x: { name = x; value = x; }) |> builtins.listToAttrs)"
  ]
}

data "external" "device_purposes" {
  program = [
    "nix",
    "eval",
    "--json",
    "github:DaRacci/nix-config#nixosConfigurations.nixio.options.host.device.purpose.type.functor.payload.elemType.functor.payload.values",
    "--apply",
    "(purposes: purposes |> builtins.map (x: { name = x; value = x; }) |> builtins.listToAttrs)"
  ]
}

data "tailscale_devices" "devices" {}

resource "tailscale_device_subnet_routes" "bling-bling-blong_routes" {
  device_id = local.bling-bling-blong.id
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

resource "tailscale_dns_nameservers" "nixio_dns" {
  nameservers = local.nixio.addresses
}

resource "tailscale_dns_preferences" "preferences" {
  magic_dns = true
}

resource "tailscale_dns_search_paths" "search_domains" {
  search_paths = ["localdomain"]
}

resource "tailscale_tailnet_settings" "settings" {
  devices_approval_on                         = true
  devices_auto_updates_on                     = true
  devices_key_duration_days                   = 180
  users_approval_on                           = true
  users_role_allowed_to_join_external_tailnet = "none"
  posture_identity_collection_on              = false
  network_flow_logging_on                     = false
}

resource "tailscale_acl" "as_hujson" {
  acl = jsonencode({
    grants = [
      {
        src = ["autogroup:admin"]
        dst = ["*"]
        ip  = ["*"]
      },

      {
        src = ["tag:ci"]
        dst = ["tag:ingress"]
        ip  = ["tcp:80-443", "udp:80-443"]
      },

      {
        src = ["autogroup:member"]
        dst = ["autogroup:self"]
        ip  = ["*"]
      }
    ]

    tests = [
      {
        src    = "tag:ci"
        accept = ["tag:ingress:443", "tag:ingress:80"]
        deny   = ["tag:server:22"]
        proto  = "tcp"
      }
    ]

    tagOwners = merge({
      "tag:nixos"   = ["autogroup:member"]
      "tag:ci"      = ["autogroup:admin"]
      "tag:ingress" = ["autogroup:admin"]
      },
      { for role in data.external.device_roles.result : "tag:${role}" => ["autogroup:member"] },
      { for purpose in data.external.device_purposes.result : "tag:${purpose}" => ["autogroup:member"] }
    )

    autoApprovers = {
      exitNode = ["tag:ingress"]
      routes = {
        "192.168.2.0/24" = ["tag:ingress"]
        "0.0.0.0/24"     = ["tag:ingress"]
        "::/0"           = ["tag:ingress"]
      }
    }
  })
}
