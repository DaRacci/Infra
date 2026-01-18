terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

variable "admin" {
  description = "Administrator email address"
  type        = string
}
