terraform {
  required_version = ">= 1.2"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.8"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}
