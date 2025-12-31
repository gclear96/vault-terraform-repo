locals {
  kubernetes_ca_cert_from_input = var.kubernetes_ca_cert_pem != null ? var.kubernetes_ca_cert_pem : (
    var.kubernetes_ca_cert_file != null ? file(var.kubernetes_ca_cert_file) : null
  )

  token_reviewer_jwt_from_input = var.token_reviewer_jwt != null ? var.token_reviewer_jwt : (
    var.token_reviewer_jwt_file != null ? file(var.token_reviewer_jwt_file) : null
  )

  kubernetes_ca_cert_effective = var.use_vault_local_sa_token ? null : local.kubernetes_ca_cert_from_input
  token_reviewer_jwt_effective = var.use_vault_local_sa_token ? null : local.token_reviewer_jwt_from_input
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = var.kubernetes_auth_path

  disable_remount = false
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_host
  disable_iss_validation = var.disable_iss_validation

  kubernetes_ca_cert = local.kubernetes_ca_cert_effective
  token_reviewer_jwt = local.token_reviewer_jwt_effective
}

resource "vault_policy" "external_secrets" {
  name   = var.external_secrets_policy_name
  policy = templatefile("${path.module}/policies/external-secrets.hcl.tftpl", { kv_mount_path = var.kv_mount_path })
}

resource "vault_mount" "kv" {
  path = var.kv_mount_path
  type = "kv"

  options = {
    version = "2"
  }

  # Match Vault's current setting to avoid a perpetual diff.
  listing_visibility = "hidden"
}

resource "vault_policy" "vault_bootstrap" {
  name   = var.vault_bootstrap_policy_name
  policy = file("${path.module}/policies/vault-bootstrap.hcl")
}

resource "vault_policy" "terraform_vault" {
  name   = var.terraform_vault_policy_name
  policy = file("${path.module}/policies/terraform-vault.hcl")
}

resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.external_secrets_role_name
  bound_service_account_names      = var.external_secrets_role_bound_service_account_names
  bound_service_account_namespaces = var.external_secrets_role_bound_service_account_namespaces

  token_policies = [vault_policy.external_secrets.name]
  token_ttl      = var.external_secrets_role_token_ttl_seconds
}
