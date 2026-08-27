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
  # Keyed by the resource objects themselves so each instance depends only on
  # its own container, not on every container in the unit.
  for_each = local.containers_by_name

  provisioner "file" {
    source      = "${local.repo_root}/scripts/init-host.sh"
    destination = "/tmp/init-host.sh"

    connection {
      type = "ssh"
      user = "root"
      host = local.proxmox_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/init-host.sh",
      # Key is piped via stdin so it never appears in argv or the process list.
      # printf %s avoids echo's backslash/flag quirks; the key is single-quoted
      # inline, which is safe because sops-managed keys contain no single quotes.
      "printf '%s' '${data.sops_file.ssh_keys.data["SSH_PRIVATE_KEYS.${each.key}"]}' | /tmp/init-host.sh ${each.key}",
      "rm -f /tmp/init-host.sh",
    ]

    connection {
      type = "ssh"
      user = "root"
      host = local.proxmox_host
    }
  }

  triggers_replace = [
    # Due to the migration from the previous proxmox provider to the new one, ids changed from "<node>:lxc:<id>" to just "<id>".
    replace(each.value.id, "/.*\\//", "")
  ]
}
