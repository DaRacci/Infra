#!/usr/bin/env nix-shell
#!nix-shell -i nushell -p lix scp


const GIT_REPO = "github:DaRacci/nix-config";
const IMAGE_FORMAT = "proxmox-lxc";
const TRANSFER_HOST = "proxmox";
const TRANSFER_DIR = "/var/lib/vz/template/cache";

def main [
  hostName: string,
] {
  let image_path = nix build $"($GIT_REPO)#nixosConfigurations.($hostName).config.formats.($IMAGE_FORMAT)" --accept-flake-config --refresh;
  scp $image_path $"root@($TRANSFER_HOST):($TRANSFER_DIR)/($hostName).tar.xz";
}
