#!/usr/bin/env bash
# Initializes a freshly created LXC container on the Proxmox host:
# adds TUN device passthrough, provisions its SSH private key into the container filesystem,
# starts it, then runs a nixos-rebuild to apply proper configuration.
#
# Must run ON the Proxmox host (uses pct/lxc-console/dtach directly).
#
# Usage: init-host.sh <hostname> <ssh_key_file>
# The SSH private key file is copied into the container before startup,
# allowing nix-config's activation scripts to detect it and skip interactive prompt.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <hostname> <ssh_key_file>" >&2
  exit 1
fi

HOSTNAME="$1"
SSH_KEY_FILE="$2"

if [ ! -f "$SSH_KEY_FILE" ]; then
  echo "SSH key file not found: $SSH_KEY_FILE" >&2
  exit 1
fi

# Exact name match on the 4th column (Name) of `pct list` output; a substring
# grep would match e.g. "nixserv" when looking up "nixserv2".
LXC_ID=$(pct list | awk -v h="$HOSTNAME" '$4 == h {print $1}')
if [ -z "$LXC_ID" ]; then
  echo "Container not found: $HOSTNAME" >&2
  exit 1
fi

# Ensure the TUN device is available in the LXC containers for WireGuard/Tailscale
LXC_CONF="/etc/pve/lxc/$LXC_ID.conf"
VALUE='lxc.cgroup.devices.allow: c 10:200 rwm'
grep -qxF -- "$VALUE" "$LXC_CONF" || echo "$VALUE" >> "$LXC_CONF"
VALUE='lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file'
grep -qxF -- "$VALUE" "$LXC_CONF" || echo "$VALUE" >> "$LXC_CONF"

# Get the actual rootfs path from container config.
# Different storage backends have different mount points.
# pct config output format: "rootfs: /path/to/rootfs,size=10G" for dir-based storage
get_rootfs_path() {
  pct config "$LXC_ID" | grep -oP '^rootfs: \K[^,]+' || return 1
}

LXC_ROOTFS=$(get_rootfs_path) || {
  echo "Warning: Could not determine container rootfs path from config, using fallback" >&2
  LXC_ROOTFS="/var/lib/lxc/$LXC_ID/rootfs"
}

if [ ! -d "$LXC_ROOTFS" ]; then
  echo "Error: Container rootfs directory does not exist: $LXC_ROOTFS" >&2
  exit 1
fi

# Provision SSH private key into container before start.
# The container's activation scripts check /var/lib/provisioning/ssh/ssh_host_ed25519_key
# If it exists, they skip the interactive console prompt.
PROVISION_DIR="$LXC_ROOTFS/var/lib/provisioning/ssh"
mkdir -p "$PROVISION_DIR"
cp "$SSH_KEY_FILE" "$PROVISION_DIR/ssh_host_ed25519_key"
chmod 600 "$PROVISION_DIR/ssh_host_ed25519_key"
rm -f "$SSH_KEY_FILE"

pct start "$LXC_ID"
until pct status "$LXC_ID" | grep -q "running"; do
  sleep 1
done

# Ensure that the Dtach session is created for the nixos-rebuild command
CONSOLE_FILE="/var/run/dtach/vzctlconsole$LXC_ID"
[ -e "$CONSOLE_FILE" ] || dtach -n "$CONSOLE_FILE" lxc-console -n "$LXC_ID" -t 0 -e -1

# Do a rebuild to ensure proper configuration
/usr/bin/echo -ne "nixos-rebuild switch --flake github:DaRacci/nix-config#$HOSTNAME --impure --accept-flake-config" | dtach -p "$CONSOLE_FILE"
