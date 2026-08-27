#!/usr/bin/env nu

use lib.nu *

const IMAGE_FORMAT = "proxmox-lxc";
const TRANSFER_HOST = "proxmox";
const TRANSFER_DIR = "/var/lib/vz/template/cache";
const BUILD_ARGS = [
  "--accept-flake-config",
  "--refresh"
];

def main [
  hostName: string,
] {
  let repo_ref = get_flake_ref
  let output_path = $"nixosConfigurations.($hostName).config.formats.($IMAGE_FORMAT)";
  let image_dir = nix build $"($repo_ref)#($output_path)" --quiet ...$BUILD_ARGS --no-link --print-out-paths;
  let image_path = ls $image_dir | get name | where { $in | str ends-with ".tar.xz" } | first;

  scp $image_path $"root@($TRANSFER_HOST):($TRANSFER_DIR)/($hostName).tar.xz";
}
