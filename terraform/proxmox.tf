locals {
  nixos_configurations = [
    "github:DaRacci/nix-config#nixserv",
    "github:DaRacci/nix-config#nixdev",
    "github:DaRacci/nix-config#nixio"
  ]
}

resource "terraform_data" "generate_nixos_configurations" {
  for_each = { for c in local.nixos_configurations : split("#", c)[1] => c }

  triggers_replace = [
    "proxmox_lxc.${each.key}"
  ]

  provisioner "local-exec" {
    command = join("; ", [
      "nix build ${each.value} -o ${each.key}.tar.xz -L --impure --accept-flake-config",
      "scp ${each.key}.tar.xz root@192.168.2.210:/var/lib/vz/template/cache/${each.key}.tar.xz",
      "rm ${each.key}.tar.xz"
    ])
  }
}

resource "terraform_data" "add_ssh_key_after_creation" {

}

resource "proxmox_lxc" "nixserv" {
  hostname     = "nixserv"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixserv.tar.xz"
  start        = true
  onboot       = true
  unprivileged = true
  cmode        = "console"

  cores  = 4
  memory = 4096
  swap   = 2048

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

  depends_on = [terraform_data.generate_nixos_configurations["nixserv"]]
}

resource "proxmox_lxc" "nixdev" {
  hostname     = "nixdev"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixdev.tar.xz"
  start        = true
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

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
    ip6    = "auto"
  }

  depends_on = [terraform_data.generate_nixos_configurations["nixdev"]]
}

resource "proxmox_lxc" "nixio" {
  hostname     = "nixio"
  target_node  = "proxmox"
  ostemplate   = "local:vztmpl/nixio.tar.xz"
  start        = true
  onboot       = true
  unprivileged = true
  cmode        = "console"

  cores  = 4
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
    mp      = "/var/lib/minio/data"
    size    = "256G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  depends_on = [terraform_data.generate_nixos_configurations["nixio"]]
}
