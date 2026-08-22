#!/usr/bin/env nix-shell
#!nix-shell -i nushell -p lix scp


const GIT_REPO = "github:DaRacci/nix-config";
const IMAGE_FORMAT = "proxmox-lxc";
const TRANSFER_HOST = "proxmox";
const TRANSFER_DIR = "/var/lib/vz/template/cache";
const BUILD_ARGS = [
  "--accept-flake-config",
  "--refresh"
];

def main [
  hostName: string,
  --branch: string = "master"
] {
  let repo_ref = $"($GIT_REPO)?ref=($branch)";
  let output_path = $"nixosConfigurations.($hostName).config.formats.($IMAGE_FORMAT)";
  let image_path = nix build $"($repo_ref)#($output_path)" ...$BUILD_ARGS;

  scp $image_path $"root@($TRANSFER_HOST):($TRANSFER_DIR)/($hostName).tar.xz";
}
