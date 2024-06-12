resource "proxmox_lxc" "nixserv" {
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixserv.tar.xz"
  onboot       = true
  unprivileged = true
  cmode        = "console"

  cores  = 2
  memory = 4096

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
    size    = "16G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
    ip6    = "auto"
  }
}

resource "proxmox_lxc" "nixdev" {
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixdev.tar.xz"
  onboot       = true
  unprivileged = true
  cmode        = "console"

  cores  = 8
  memory = 8196

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
}
