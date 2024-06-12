terraform {
  backend "remote" {
    organization = "racci"
    workspaces { name = "infra" }
  }
}
