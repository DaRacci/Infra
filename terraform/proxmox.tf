locals {
  all_containers = [for k, v in proxmox_lxc.containers : v]
  nixos_configurations = [
    "nixmon",
    "nixarr",
    "nixcloud",
    "nixserv",
    "nixdev",
    "nixio",
    "nixai"
  ]

  # Default values for containers
  container_defaults = {
    rootfs_size = "16G"
    memory      = 2048
    swap        = null
    features = {
      nesting = true
      fuse    = false
    }
  }

  container_configs = {
    nixserv = {
      cores    = 8
      cpuunits = 80
      memory   = 8192
      swap     = 4096
      mountpoint = {
        key     = 0
        slot    = 0
        storage = "local-zfs"
        mp      = "/nix/store"
        size    = "128G"
      }
    }
    nixdev = {
      cores    = 8
      cpuunits = 105
      memory   = 16384
      mountpoint = {
        key     = 0
        slot    = 0
        storage = "local-zfs"
        mp      = "/var/lib/coder"
        size    = "128G"
      }
    }
    nixio = {
      cores    = 6
      cpuunits = 120
      memory   = 4096
      mountpoint = {
        key     = 0
        slot    = 0
        storage = "local-zfs"
        mp      = "/var/lib/minio/data"
        size    = "512G"
      }
    }
    nixarr = {
      cores    = 4
      cpuunits = 90
      memory   = 4096
      mountpoint = {
        key     = 0
        slot    = 0
        storage = "naspool"
        mp      = "/data/media"
        size    = "2056G"
        backup  = false
      }
    }
    nixcloud = {
      cores       = 8
      cpuunits    = 110
      memory      = 8196
      rootfs_size = "32G"
      features = {
        fuse = true
      }
    }
    nixmon = {
      cores    = 2
      cpuunits = 75
      memory   = 1024
    }
    nixai = {
      cores       = 16
      cpuunits    = 75
      memory      = 16384
      rootfs_size = "96G"
    }
  }
}

# TODO - Automatically create new up to date images upon a new commit to the nix-config repository
resource "terraform_data" "nixos_configurations" {
  for_each = { for val in local.nixos_configurations : val => val }
  provisioner "local-exec" {
    command = "./scripts/build-image-and-transfer.nu ${each.key}"
  }
}

resource "terraform_data" "init_after_creation" {
  for_each = { for idx, val in local.all_containers : val.hostname => val }

  provisioner "remote-exec" {
    inline = [
      "LXC_ID=$(pct list | grep \"${each.value.hostname}\" | awk '{print $1}')",
      "[ -z \"$LXC_ID\" ] && echo \"Container not found\" && exit 1",
      "LXC_CONF=/etc/pve/lxc/\"$LXC_ID\".conf",

      #region Ensure the TUN device is available in the LXC containers for WireGuard/Tailscale
      "VALUE='lxc.cgroup.devices.allow: c 10:200 rwm' && grep -qxF -- \"$VALUE\" \"$LXC_CONF\" || echo \"$VALUE\" >> \"$LXC_CONF\"",
      "VALUE='lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' && grep -qxF -- \"$VALUE\" \"$LXC_CONF\" || echo \"$VALUE\" >> \"$LXC_CONF\"",
      #endregion

      "pct start \"$LXC_ID\"",
      "while [ $(pct status \"$LXC_ID\" | grep \"running\" | wc -l) -eq 0 ]; do sleep 1; done",

      #region Input the SSH Private key into the LXC container
      # Once the Container started for the first time,
      # we need to input its SSH Private key into the stdinput, followed by Ctrl+D to continue.
      # This is required so we don't build the image with the SSH Private key in it.

      # Ensure that the Dtach session is created before sending the SSH Private key
      "CONSOLE_FILE=/var/run/dtach/vzctlconsole\"$LXC_ID\"",
      "[ -e \"$CONSOLE_FILE\" ] || dtach -n \"$CONSOLE_FILE\" lxc-console -n \"$LXC_ID\" -t 0 -e -1",

      # Send the SSH Private key to the LXC container followed by Ctrl+D
      # Use the full path so we don't use the bash built-in echo
      "/usr/bin/echo -ne \"${data.sops_file.ssh_keys.data["SSH_PRIVATE_KEYS.${each.value.hostname}"]}\\n\\x04\" | dtach -p \"$CONSOLE_FILE\"",
      #endregion

      #region Do a rebuild to ensure proper configuration
      "/usr/bin/echo -ne \"nixos-rebuild switch --flake github:DaRacci/nix-config#${each.key} --impure --accept-flake-config\" | dtach -p \"$CONSOLE_FILE\""
      #endregion
    ]

    connection {
      type = "ssh"
      user = "root"
      host = local.proxmox_host
    }
  }

  triggers_replace = [
    each.value.id
  ]
}

resource "proxmox_lxc" "containers" {
  for_each = local.container_configs

  hostname     = each.key
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/${each.key}.tar.xz"
  unprivileged = true
  onboot       = true
  cmode        = "console"

  cores    = each.value.cores
  cpulimit = try(each.value.cpulimit, null)
  cpuunits = each.value.cpuunits
  memory   = lookup(each.value, "memory", local.container_defaults.memory)

  features {
    nesting = lookup(lookup(each.value, "features", {}), "nesting", local.container_defaults.features.nesting)
    fuse    = lookup(lookup(each.value, "features", {}), "fuse", local.container_defaults.features.fuse)
  }

  rootfs {
    storage = "local-zfs"
    size    = lookup(each.value, "rootfs_size", local.container_defaults.rootfs_size)
  }

  dynamic "mountpoint" {
    for_each = try(each.value.mountpoint, null) != null ? [each.value.mountpoint] : []
    content {
      key     = mountpoint.value.key
      slot    = mountpoint.value.slot
      storage = mountpoint.value.storage
      mp      = mountpoint.value.mp
      size    = mountpoint.value.size
      backup  = try(mountpoint.value.backup, null)
    }
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
    ip6    = "dhcp"
  }

  depends_on = [terraform_data.nixos_configurations]
}
