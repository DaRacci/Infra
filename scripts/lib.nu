const ENV_FILE = ".env"

export-env {
  read-env
}

def --env read-env [] {
  let repo_root = git rev-parse --show-toplevel | str trim
  let env_path = $"($repo_root)/($ENV_FILE)"

  let parsed = open $env_path
    | lines
    | parse "{key}={value}"
    | where {
      # Don't override already set env vars
      let key = $in.key
      ($env | get -o $key) | is-empty
    }

  $parsed | transpose -d -r | load-env
}


export def get_flake_ref [] {
  let OWNER = $env.NIX_CONFIG_OWNER
  let REPO = $env.NIX_CONFIG_REPO
  let BRANCH = $env.NIX_CONFIG_BRANCH;

  return $"github:($OWNER)/($REPO)?ref=($BRANCH)"
}
