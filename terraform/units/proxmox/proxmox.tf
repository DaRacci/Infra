# data "external" "nix-config_commit-hash" {
#   program = ["nu", "../scripts/get-commit.nu"]
# }

data "external" "nixos_hosts" {
  program = ["nu", "${local.repo_root}/scripts/get-servers.nu"]
}

locals {
  nixos_configurations = keys(data.external.nixos_hosts.result)

  proxmox_host = data.sops_file.secrets.data["PROXMOX.HOST"]

  containers_by_name = {
    nixserv  = proxmox_virtual_environment_container.nixserv
    nixdev   = proxmox_virtual_environment_container.nixdev
    nixio    = proxmox_virtual_environment_container.nixio
    nixarr   = proxmox_virtual_environment_container.nixarr
    nixcloud = proxmox_virtual_environment_container.nixcloud
    nixmon   = proxmox_virtual_environment_container.nixmon
    nixai    = proxmox_virtual_environment_container.nixai
    nixstor  = proxmox_virtual_environment_container.nixstor
    nixdb    = proxmox_virtual_environment_container.nixdb
    nixauth  = proxmox_virtual_environment_container.nixauth
  }

  container_names = keys(local.containers_by_name)
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
  for_each = toset(local.container_names)

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
    replace(local.containers_by_name[each.key].id, "/.*\\//", "")
  ]

  depends_on = [
    proxmox_virtual_environment_container.nixserv,
    proxmox_virtual_environment_container.nixdev,
    proxmox_virtual_environment_container.nixio,
    proxmox_virtual_environment_container.nixarr,
    proxmox_virtual_environment_container.nixcloud,
    proxmox_virtual_environment_container.nixmon,
    proxmox_virtual_environment_container.nixai,
    proxmox_virtual_environment_container.nixstor,
    proxmox_virtual_environment_container.nixdb,
    proxmox_virtual_environment_container.nixauth,
  ]
}
