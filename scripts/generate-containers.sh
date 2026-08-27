#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
OUT="$REPO_ROOT/terraform/units/proxmox/containers.tf.json"

store_path="$(nix build --no-link --print-out-paths "$REPO_ROOT#proxmoxContainersJson")"
cat "$store_path" > "$OUT"
