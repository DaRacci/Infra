locals {
  all_containers = [proxmox_lxc.nixserv, proxmox_lxc.nixmon, proxmox_lxc.nixdev, proxmox_lxc.nixio, proxmox_lxc.nixarr, proxmox_lxc.nixcloud]
  nixos_configurations = [
    "nixmon",
    "nixarr",
    "nixcloud",
    "nixserv",
    "nixdev",
    "nixio",
  ]
}

resource "terraform_data" "nixos_configurations" {
  for_each = { for val in local.nixos_configurations : val => val }

  triggers_replace = [
    "proxmox_lxc.${each.key}.id"
  ]

  provisioner "local-exec" {
    command = "nix build github:DaRacci/nix-config#nixosConfigurations.${each.key}.config.formats.proxmox-lxc -o /tmp/${each.key}-build -L --impure --accept-flake-config --refresh"
  }

  provisioner "file" {
    source      = "/tmp/${each.key}-build/nixos-system-x86_64-linux.tar.xz"
    destination = "/var/lib/vz/template/cache/${each.key}.tar.xz"

    connection {
      type = "ssh"
      user = "root"
      host = local.proxmox_host
    }
  }

  provisioner "local-exec" {
    command = "rm -rf ${each.key}-build"
  }
}

resource "terraform_data" "init_after_creation" {
  for_each = { for idx, val in local.all_containers : val.hostname => val }

  # Ensure the TUN device is available in the LXC containers for WireGuard/Tailscale
  provisioner "remote-exec" {
    inline = [
      # Adds the TUN device to the LXC containers by adding the following lines to the lxc.conf file:
      # lxc.cgroup.devices.allow: c 10:200 rwm
      # lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
      # Get the ID of the LXC container
      "id=$(pct list | grep ${each.value.hostname} | awk '{print $1}')",
      "echo 'lxc.cgroup.devices.allow: c 10:200 rwm' >> /etc/pve/lxc/$id.conf",
      "echo 'lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' >> /etc/pve/lxc/$id.conf",
      "pct start $id"
    ]

    connection {
      type = "ssh"
      user = "root"
      host = local.proxmox_host
    }
  }

  # Once the Container started for the first time,
  # we need to input its SSH Private key into the stdinput, followed by Ctrl+D to continue.
  # This is required so we don't build the image with the SSH Private key in it.
  provisioner "remote-exec" {
    inline = [
      "LXC_ID=$(pct list | grep ${each.value.hostname} | awk '{print $1}')",
      # Ensure that the Dtach session is created before sending the SSH Private key
      "[ -e /var/run/dtach/vzctlconsole$LXC_ID ] || dtach -n /var/run/dtach/vzctlconsole$LXC_ID lxc-console -n \"$LXC_ID\" -t 0 -e -1",

      # TODO: Is there a way to get the private key from the sops file in the nix-config repo?
      # Send the SSH Private key to the LXC container followed by Ctrl+D
      # Use the full path so we don't use the bash built-in echo
      "/usr/bin/echo -ne \"${data.sops_file.ssh_keys.data["SSH_PRIVATE_KEYS.${each.value.hostname}"]}\\n\\x04\" | dtach -p \"/var/run/dtach/vzctlconsole$LXC_ID\""
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

resource "proxmox_lxc" "nixserv" {
  hostname     = "nixserv"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixserv.tar.xz"
  unprivileged = true
  onboot       = true
  cmode        = "console"

  cpuunits = 80
  memory   = 8192
  swap     = 4096

  features {
    nesting = true
  }

  rootfs {
    storage = "local-zfs"
    size    = "8G"
  }

  mountpoint {
    key     = 0
    slot    = 0
    storage = "local-zfs"
    mp      = "/nix/store"
    size    = "128G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  depends_on = [terraform_data.nixos_configurations["nixserv"]]
}

resource "proxmox_lxc" "nixdev" {
  hostname     = "nixdev"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixdev.tar.xz"
  unprivileged = true
  onboot       = true
  cmode        = "console"

  cores    = 8
  cpuunits = 105
  memory   = 8196

  features {
    nesting = true
  }

  rootfs {
    storage = "local-zfs"
    size    = "8G"
  }

  mountpoint {
    key     = 0
    slot    = 0
    storage = "local-zfs"
    mp      = "/var/lib/coder"
    size    = "128G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
    ip6    = "auto"
  }

  depends_on = [terraform_data.nixos_configurations["nixdev"]]
}

resource "proxmox_lxc" "nixio" {
  hostname     = "nixio"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixio.tar.xz"
  unprivileged = true
  onboot       = true
  cmode        = "console"

  cores    = 6
  cpulimit = 400
  cpuunits = 120
  memory   = 8196

  features {
    nesting = true
  }

  rootfs {
    storage = "local-zfs"
    size    = "8G"
  }

  mountpoint {
    key     = 0
    slot    = 0
    storage = "local-zfs"
    mp      = "/var/lib/minio/data"
    size    = "256G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  depends_on = [terraform_data.nixos_configurations["nixio"]]
}

resource "proxmox_lxc" "nixarr" {
  hostname     = "nixarr"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixarr.tar.xz"
  unprivileged = true
  onboot       = true
  cmode        = "console"

  cores    = 4
  cpulimit = 200
  cpuunits = 90
  memory   = 4096
  swap     = 2048

  features {
    nesting = true
  }

  rootfs {
    storage = "local-zfs"
    size    = "16G"
  }

  mountpoint {
    key     = 0
    slot    = 0
    storage = "jellypool"
    mp      = "/data/media"
    size    = "512G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  depends_on = [terraform_data.nixos_configurations["nixarr"]]
}

resource "proxmox_lxc" "nixcloud" {
  hostname     = "nixcloud"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixcloud.tar.xz"
  unprivileged = true
  onboot       = true
  cmode        = "console"

  cores    = 8
  cpulimit = 400
  cpuunits = 110
  memory   = 8196
  swap     = 2048

  features {
    nesting = true
  }

  rootfs {
    storage = "local-zfs"
    size    = "16G"
  }

  mountpoint {
    key     = 0
    slot    = 0
    storage = "jellypool"
    mp      = "/data/media"
    size    = "512G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  depends_on = [terraform_data.nixos_configurations["nixcloud"]]
}

resource "proxmox_lxc" "nixmon" {
  hostname     = "nixmon"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixmon.tar.xz"
  unprivileged = true
  onboot       = true
  cmode        = "console"

  cores    = 2
  cpulimit = 100
  cpuunits = 75
  memory   = 4098
  swap     = 2048

  features {
    nesting = true
  }

  rootfs {
    storage = "local-zfs"
    size    = "16G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  depends_on = [terraform_data.nixos_configurations["nixmon"]]
}
