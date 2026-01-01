provider "vault" {
  address          = var.vault_addr
  skip_child_token = var.vault_skip_child_token
}
