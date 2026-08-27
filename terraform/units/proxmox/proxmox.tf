# data "external" "nix-config_commit-hash" {
#   program = ["nu", "../scripts/get-commit.nu"]
# }

data "external" "nixos_hosts" {
  program = ["nu", "${local.repo_root}/scripts/get-servers.nu"]
}

locals {
  all_containers       = [for k, v in proxmox_virtual_environment_container.containers : v]
  nixos_configurations = keys(data.external.nixos_hosts.result)

  proxmox_host = data.sops_file.secrets.data["PROXMOX.HOST"]

  secure_mount_options = ["noatime", "lazytime", "nodev", "noexec", "nosuid"]

  container_settings = {
    for name, cfg in local.container_configs :
    name => merge(
      {
        for section, defaults in local.container_defaults :
        section => merge(defaults, try(cfg[section], {}))
      },
      {
        for section, val in cfg :
        section => val if !can(local.container_defaults[section])
      }
    )
  }

  # Default values for containers
  container_defaults = {
    cpu = {
      cores = 2
      limit = 0
      units = 1024
    }

    memory = {
      dedicated = 2048
      swap      = 0
    }

    disk = {
      size = 16
    }

    features = {
      nesting = true
      fuse    = false
    }
  }

  container_rocm_acceleration = {
    #TODO:can't remember where these magic uid and gid came from
    device_passthrogh = [
      {
        uid  = 0
        gid  = 26
        mode = "0660"
        path = "/dev/dri/renderD128"
      },
      {
        uid  = 0
        gid  = 303
        mode = "0660"
        path = "/dev/kfd"
      }
    ]
  }

  container_configs = {
    nixserv = {
      cpu = {
        cores = 8
        units = 80
      }

      memory = {
        dedicated = 8192
      }

      mount_point = {
        volume = "local-zfs"
        path   = "/nix/store"
        size   = "128G"
        backup = false
      }
    }

    nixdev = {
      cpu = {
        cores = 8
        units = 105
      }

      memory = {
        dedicated = 16384
      }

      disk = {
        size = 32
      }

      features = {
        fuse = true
      }

      mount_point = {
        volume = "local-zfs"
        path   = "/var/lib/coder"
        size   = "128G"
        backup = false
      }
    }

    nixio = {
      cpu = {
        cores = 6
        units = 120
      }

      memory = {
        dedicated = 4096
      }

      features = {
        fuse = true
      }

      mount_point = [
        {
          volume = "local-zfs:subvol-105-disk-1"
          path   = "/var/lib/minio/data"
          size   = "512G"
          backup = false
        },
        {
          volume = "fast"
          path   = "/var/lib/seaweedfs"
          size   = "512G"
          backup = false
        }
      ]
    }

    nixarr = merge({
      cpu = {
        cores = 4
        units = 90
        limit = 200
      }

      memory = {
        dedicated = 12288
        swap      = 2048
      }

      disk = {
        size = 24
      }

      mount_point = {
        volume        = "fast"
        path          = "/data/media"
        size          = "4156G"
        backup        = false
        mount_options = ["noatime"]
      }
    }, local.container_rocm_acceleration)

    nixcloud = {
      cpu = {
        cores = 8
        units = 110
      }

      memory = {
        dedicated = 16384
        swap      = 4096
      }

      disk = {
        size = 32
      }

      features = {
        fuse = true
      }

      mount_point = {
        # TODO: dont hardcode the volume name
        volume        = "/fast/subvol-106-disk-0"
        path          = "/mnt/media/"
        read_only     = true
        backup        = false
        mount_options = ["noatime", "lazytime"]
      }
    }

    nixmon = {
      cpu = {
        cores = 2
        units = 75
      }

      memory = {
        dedicated = 8192
        swap      = 2048
      }

      features = {
        fuse = true
      }

      mount_point = [
        {
          volume        = "fast:subvol-108-disk-0"
          path          = "/var/lib/prometheus2"
          size          = "32G"
          backup        = true
          mount_options = local.secure_mount_options
        },
        {
          volume        = "fast:subvol-108-disk-1"
          path          = "/var/lib/loki"
          size          = "8G"
          backup        = false
          mount_options = local.secure_mount_options
        }
      ]
    }

    nixai = (merge({
      cpu = {
        cores = 16
        units = 75
        limit = 100
      }

      memory = {
        dedicated = 24576
        swap      = 2048
      }

      disk = {
        size = 96
      }

      mount_point = {
        volume = "fast:subvol-103-disk-0"
        path   = "/var/lib/hermes"
        size   = "64G"
        backup = true
      }
    }, local.container_rocm_acceleration))

    nixstor = {
      cpu = {
        cores = 8
        units = 100
      }

      memory = {
        dedicated = 8192
      }

      disk = {
        size = 16
      }
      mount_point = {
        volume = "fast"
        path   = "/var/lib/seaweedfs"
        size   = "1T"
        backup = false
      }
    }

    nixdb = {
      cpu = {
        cores = 4
        units = 100
      }

      memory = {
        dedicated = 4096
      }

      disk = {
        size = 16
      }

      mount_point = [
        {
          volume        = "fast"
          path          = "/var/lib/postgresql"
          size          = "64G"
          backup        = true
          mount_options = local.secure_mount_options
        },
        {
          volume        = "fast"
          path          = "/var/lib/postgresql/backup"
          size          = "64G"
          backup        = false
          mount_options = local.secure_mount_options
        }
      ]
    }

    nixauth = {
      cpu = {
        cores = 2
        units = 100
      }

      memory = {
        dedicated = 1024
      }

      disk = {
        size = 8
      }

      mount_point = [
        {
          volume        = "fast"
          path          = "/var/lib/kanidm"
          size          = "4G"
          backup        = true
          mount_options = local.secure_mount_options
        },
        {
          volume        = "fast"
          path          = "/var/lib/kanidm/backup"
          size          = "4G"
          backup        = false
          mount_options = local.secure_mount_options
        }
      ]
    }
  }
}

# TODO - Automatically create new up to date images upon a new commit to the nix-config repository
resource "terraform_data" "nixos_configurations" {
  for_each = { for val in local.nixos_configurations : val => val }
  provisioner "local-exec" {
    command = "${local.repo_root}/scripts/build-image-and-transfer.nu ${each.key}"
  }

  # triggers_replace = [
  #   data.external.nix-config_commit-hash.result.sha
  # ]
}

resource "terraform_data" "init_after_creation" {
  for_each = local.container_configs

  provisioner "remote-exec" {
    inline = [
      "LXC_ID=$(pct list | grep \"${each.key}\" | awk '{print $1}')",
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
      "/usr/bin/echo -ne \"${data.sops_file.ssh_keys.data["SSH_PRIVATE_KEYS.${each.key}"]}\\n\\x04\" | dtach -p \"$CONSOLE_FILE\"",
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
    # Due to the migration from the previous proxmox provider to the new one, ids changed from "<node>:lxc:<id>" to just "<id>".
    replace(proxmox_virtual_environment_container.containers[each.key].id, "/.*\\//", "")
  ]

  depends_on = [proxmox_virtual_environment_container.containers]
}

resource "proxmox_virtual_environment_container" "containers" {
  for_each = local.container_configs

  node_name     = "proxmox"
  unprivileged  = true
  start_on_boot = true
  started       = true

  operating_system {
    template_file_id = "local:vztmpl/${each.key}.tar.xz"
    type             = "nixos"
  }

  initialization {
    hostname = each.key
    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }

  console {
    enabled   = true
    type      = "console"
    tty_count = 2
  }

  cpu {
    cores = local.container_settings[each.key].cpu.cores
    limit = local.container_settings[each.key].cpu.limit
    units = local.container_settings[each.key].cpu.units
  }

  memory {
    dedicated = local.container_settings[each.key].memory.dedicated
    swap      = local.container_settings[each.key].memory.swap
  }

  features {
    nesting = local.container_settings[each.key].features.nesting
    fuse    = local.container_settings[each.key].features.fuse
  }

  disk {
    datastore_id = "local-zfs"
    size         = local.container_settings[each.key].disk.size
  }

  dynamic "mount_point" {
    for_each = try(flatten([each.value.mount_point]), [])
    content {
      volume        = mount_point.value.volume
      path          = mount_point.value.path
      size          = try(mount_point.value.size, null)
      backup        = try(mount_point.value.backup, true)
      read_only     = try(mount_point.value.read_only, false)
      mount_options = try(mount_point.value.mount_options, null)
    }
  }

  dynamic "device_passthrough" {
    for_each = try(flatten([each.value.device_passthrogh]), [])
    content {
      uid  = device_passthrough.value.uid
      gid  = device_passthrough.value.gid
      mode = device_passthrough.value.mode
      path = device_passthrough.value.path
    }
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  depends_on = [terraform_data.nixos_configurations]
}
