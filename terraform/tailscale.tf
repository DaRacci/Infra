locals {
  bling-bling-blong = [for device in data.tailscale_devices.devices.devices : device if device.name == "bling-bling-blong.degu-beta.ts.net"][0]
  nixio             = [for device in data.tailscale_devices.devices.devices : device if device.name == "nixio.degu-beta.ts.net"][0]

  # Tag lists for device classification (from nix-config type system)
  device_role_tags    = [for role in keys(data.external.device_roles.result) : "tag:${role}"]
  device_purpose_tags = [for purpose in keys(data.external.device_purposes.result) : "tag:${purpose}"]
  # All member-owned device tags (roles + purposes) that should have full access
  device_class_tags = concat(local.device_role_tags, local.device_purpose_tags)
}

data "external" "device_roles" {
  program = [
    "nix",
    "eval",
    "--json",
    "github:DaRacci/nix-config#nixosConfigurations.nixio.options.host.device.role.type.functor.payload.elemType.functor.payload.values",
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
      # Admin: unrestricted access to whole tailnet
      {
        src = ["autogroup:admin"]
        dst = ["*"]
        ip  = ["*"]
      },

      # CI runners (GitHub Actions): HTTP/HTTPS/DNS to ingress hosts only (cache.racci.dev)
      {
        src = ["tag:ci"]
        dst = ["tag:ingress"]
        ip  = ["tcp:80", "tcp:443", "udp:80", "udp:443", "udp:53"]
      },

      # Everyone else: full access
      # autogroup:member covers interactively-logged-in devices (phones, tablets, Apple TV, etc.)
      # device_class_tags covers ephemeral NixOS hosts with role/purpose tags (tag:server, tag:desktop, etc.)
      {
        src = concat(["autogroup:member"], local.device_class_tags)
        dst = ["*"]
        ip  = ["*"]
      },
    ]

    tagOwners = merge({
      "tag:ci"       = ["autogroup:admin"]
      "tag:ingress"  = ["autogroup:admin"]
      "tag:headless" = ["autogroup:member"]
      "tag:nixos"    = ["autogroup:member"]
      "tag:server"   = ["autogroup:member"]
      "tag:virtual"  = ["autogroup:member"]
      },
      { for role in data.external.device_roles.result : "tag:${role}" => ["autogroup:member"] },
      { for purpose in data.external.device_purposes.result : "tag:${purpose}" => ["autogroup:member"] }
    )

    autoApprovers = {
      exitNode = ["tag:ingress"]
      routes = {
        "0.0.0.0/24"     = ["tag:ingress"]
        "::/0"           = ["tag:ingress"]
        "192.168.1.0/24" = ["tag:ingress"]
        "192.168.2.0/24" = ["tag:ingress"]
      }
    }

    tests = [
      # === CI runner restrictions ===
      {
        src    = "tag:ci"
        accept = ["tag:ingress:80", "tag:ingress:443"]
        proto  = "tcp"
      },
      {
        src    = "tag:ci"
        accept = ["tag:ingress:53"]
        proto  = "udp"
      },
      {
        src  = "tag:ci"
        deny = ["tag:ingress:22"]
      },
      {
        src  = "tag:ci"
        deny = ["tag:server:22", "tag:desktop:22"]
      },

      # === Non-restricted devices ===
      {
        src    = "me@racci.dev"
        accept = ["tag:ingress:80", "tag:ingress:443", "tag:ingress:22", "tag:ingress:53"]
      },
      {
        src    = "tag:server"
        accept = ["tag:ingress:80", "tag:ingress:443"]
      },
      {
        src    = "tag:desktop"
        accept = ["tag:server:22", "tag:ingress:53", "tag:ingress:80", "tag:ingress:443"]
      },
      {
        src    = "tag:laptop"
        accept = ["tag:server:22", "tag:ingress:53", "tag:ingress:80", "tag:ingress:443"]
      },
    ]
  })
}
