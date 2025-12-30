terraform {
  # Remote state in Garage (S3-compatible).
  #
  # This is intentionally partial: supply the Garage endpoint and S3-compat flags
  # via `terraform init -backend-config=...` (see README / scripts).
  backend "s3" {
    bucket = "tf-state"
    key    = "vault/terraform.tfstate"
    region = "garage"
  }
}
