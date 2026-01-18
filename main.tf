locals {
  kubernetes_ca_cert_from_input = var.kubernetes_ca_cert_pem != null ? var.kubernetes_ca_cert_pem : (
    var.kubernetes_ca_cert_file != null ? file(var.kubernetes_ca_cert_file) : null
  )

  token_reviewer_jwt_from_input = var.token_reviewer_jwt != null ? var.token_reviewer_jwt : (
    var.token_reviewer_jwt_file != null ? file(var.token_reviewer_jwt_file) : null
  )

  kubernetes_ca_cert_effective = var.use_vault_local_sa_token ? null : local.kubernetes_ca_cert_from_input
  token_reviewer_jwt_effective = var.use_vault_local_sa_token ? null : local.token_reviewer_jwt_from_input

  oidc_config_base = {
    oidc_discovery_url = var.oidc_discovery_url
    oidc_client_id     = var.oidc_client_id
    default_role       = var.oidc_default_role
  }
  oidc_enabled = var.oidc_client_secret != null && var.oidc_client_secret != ""
  oidc_config_effective = local.oidc_enabled ? merge(
    local.oidc_config_base,
    { oidc_client_secret = var.oidc_client_secret }
  ) : local.oidc_config_base
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

resource "vault_auth_backend" "oidc" {
  count = local.oidc_enabled ? 1 : 0

  type = "oidc"
  path = var.oidc_auth_path

  disable_remount = false
}

resource "vault_generic_endpoint" "oidc_config" {
  count = local.oidc_enabled ? 1 : 0

  path      = "auth/${var.oidc_auth_path}/config"
  data_json = jsonencode(local.oidc_config_effective)

  depends_on = [vault_auth_backend.oidc]
}

resource "vault_generic_endpoint" "oidc_role" {
  count = local.oidc_enabled ? 1 : 0

  path = "auth/${var.oidc_auth_path}/role/${var.oidc_default_role}"
  data_json = jsonencode({
    bound_audiences       = var.oidc_bound_audiences
    allowed_redirect_uris = var.oidc_allowed_redirect_uris
    user_claim            = var.oidc_user_claim
    groups_claim          = var.oidc_groups_claim
    oidc_scopes           = var.oidc_scopes
    policies              = var.oidc_role_policies
  })

  depends_on = [vault_generic_endpoint.oidc_config]
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

resource "vault_kv_secret_v2" "democratic_csi_truenas" {
  count = var.manage_democratic_csi_truenas_secret ? 1 : 0

  mount = vault_mount.kv.path
  name  = var.democratic_csi_truenas_secret_name

  data_json = jsonencode({
    username     = var.democratic_csi_truenas_username
    password     = var.democratic_csi_truenas_password
    ssh_password = var.democratic_csi_truenas_ssh_password
  })

  depends_on = [vault_mount.kv]
}

resource "vault_policy" "vault_bootstrap" {
  name   = var.vault_bootstrap_policy_name
  policy = file("${path.module}/policies/vault-bootstrap.hcl")
}

resource "vault_policy" "terraform_vault" {
  name   = var.terraform_vault_policy_name
  policy = file("${path.module}/policies/terraform-vault.hcl")
}

resource "vault_policy" "vault_admin" {
  name   = var.vault_admin_policy_name
  policy = file("${path.module}/policies/vault-admin.hcl")
}

resource "vault_identity_group" "oidc_admin" {
  count = local.oidc_enabled && var.oidc_admin_group != null ? 1 : 0

  name     = var.oidc_admin_group
  type     = "external"
  policies = [vault_policy.vault_admin.name]
}

resource "vault_identity_group_alias" "oidc_admin" {
  count = local.oidc_enabled && var.oidc_admin_group != null ? 1 : 0

  name           = var.oidc_admin_group
  mount_accessor = vault_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.oidc_admin[0].id
}

resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = var.external_secrets_role_name
  bound_service_account_names      = var.external_secrets_role_bound_service_account_names
  bound_service_account_namespaces = var.external_secrets_role_bound_service_account_namespaces

  token_policies = [vault_policy.external_secrets.name]
  token_ttl      = var.external_secrets_role_token_ttl_seconds
}
