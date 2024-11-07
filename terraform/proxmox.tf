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
    command = "nix build github:DaRacci/nix-config#nixosConfigurations.${each.value}.config.formats.proxmox-lxc -o ${each.key}.tar.xz -L --impure --accept-flake-config --refresh"
  }

  provisioner "file" {
    source      = "${each.key}.tar.xz"
    destination = "/var/lib/vz/template/cache/${each.key}.tar.xz"

    connection {
      type = "ssh"
      user = "root"
      host = "192.168.2.210"
    }
  }

  provisioner "local-exec" {
    command = "rm ${each.key}.tar.xz"
  }
}

resource "terraform_data" "init_after_creation" {
  for_each = { for idx, val in local.all_containers : val.hostname => val }

  # Adds the TUN device to the LXC containers by adding the following lines to the lxc.conf file:
  # lxc.cgroup.devices.allow: c 10:200 rwm
  # lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
  provisioner "remote-exec" {
    inline = [
      # Get the ID of the LXC container
      "id=$(pct list | grep ${each.value.hostname} | awk '{print $1}')",
      "echo 'lxc.cgroup.devices.allow: c 10:200 rwm' >> /etc/pve/lxc/$id.conf",
      "echo 'lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' >> /etc/pve/lxc/$id.conf",
      "pct start $id"
    ]

    connection {
      type = "ssh"
      user = "root"
      host = "192.168.2.210"
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

  cores    = 4
  cpulimit = 300
  cpuunits = 80
  memory   = 4096
  swap     = 2048

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
