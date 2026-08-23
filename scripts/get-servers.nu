#!/usr/bin/env nu

use lib.nu *

def main [] {
  let flake_ref = get_flake_ref
  nix eval --json $"($flake_ref)#nixosConfigurations" --apply '(
    x: builtins.listToAttrs (
      builtins.map
        (name: {
          name = name;
          value = name;
        })
        (builtins.filter
          (name: ((builtins.getAttr name x).config.host.device.role or "") == "server")
          (builtins.attrNames x))
    )
  )'
}
