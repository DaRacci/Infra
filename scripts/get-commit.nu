#!/usr/bin/env nu

use lib.nu *

let OWNER = $env.NIX_CONFIG_OWNER
let REPO = $env.NIX_CONFIG_REPO
let BRANCH = $env.NIX_CONFIG_BRANCH

def main [] {
  let url = $"https://api.github.com/repos/($OWNER)/($REPO)/commits/($BRANCH)"
  let value = http get $url
    | select sha
    | to json

  return $value
}
