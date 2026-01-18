#!/usr/bin/env nu

const OWNER = "DaRacci"
const REPO = "nix-config"
const BRANCH  = "master"

def main [] {
  let url = $"https://api.github.com/repos/($OWNER)/($REPO)/commits/($BRANCH)"
  let value = http get $url
    | select sha
    | to json

  return $value
}
