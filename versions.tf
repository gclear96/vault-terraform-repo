terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vault = {
      source = "hashicorp/vault"
      # Provider 5.x requires Terraform >= 1.11; pin 4.x to keep this repo usable on older Terraform/OpenTofu.
      version = ">= 4.7.0, < 5.0.0"
    }
  }
}
