#!/usr/bin/env bash

if [ -z "$2" ]; then
  echo "Usage: $0 <hostname> <ssh_private_key>"
  exit 1
fi

HOSTNAME="$1"
SSH_PRIVATE_KEY="$2"

LXC_ID=$(pct list | grep "$HOSTNAME" | awk '{print $1}')
if [ -z "$LXC_ID" ]; then
  echo "Container not found"
  exit 1
fi

# Ensure the TUN device is available in the LXC containers for WireGuard/Tailscale
LXC_CONF=/etc/pve/lxc/"$LXC_ID".conf
VALUE='lxc.cgroup.devices.allow: c 10:200 rwm' && grep -qxF -- "$VALUE" "$LXC_CONF" || echo "$VALUE" >> "$LXC_CONF"
VALUE='lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' && grep -qxF -- "$VALUE" "$LXC_CONF" || echo "$VALUE" >> "$LXC_CONF"

pct start "$LXC_ID"
while [ "$(pct status "$LXC_ID" | grep -c "running")" -eq 0 ]; do
  sleep 1;
done

# Ensure that the Dtach session is created before sending the SSH Private key
CONSOLE_FILE=/var/run/dtach/vzctlconsole"$LXC_ID"
[ -e "$CONSOLE_FILE" ] || dtach -n "$CONSOLE_FILE" lxc-console -n "$LXC_ID" -t 0 -e -1

# Send the SSH Private key to the LXC container followed by Ctrl+D
# Use the full path so we don't use the bash built-in echo
/usr/bin/echo -ne "$SSH_PRIVATE_KEY\n\x04" | dtach -p "$CONSOLE_FILE"

# Do a rebuild to ensure proper configuration
/usr/bin/echo -ne "nixos-rebuild switch --flake github:DaRacci/nix-config#$HOSTNAME --accept-flake-config" | dtach -p "$CONSOLE_FILE"
