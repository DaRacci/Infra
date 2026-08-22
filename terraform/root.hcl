generate "sops" {
  path      = "sops.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    data "sops_file" "secrets" {
      source_file = "${get_repo_root()}/terraform/secrets.yaml"
    }

    data "sops_file" "ssh_keys" {
      source_file = "${get_repo_root()}/terraform/host-keys.yaml"
    }
  EOT
}

generate "repo_root" {
  path      = "repo_root.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    locals {
      repo_root = "${get_repo_root()}"
    }
  EOT
}
