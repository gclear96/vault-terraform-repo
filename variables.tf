variable "vault_addr" {
  type        = string
  description = "Vault address for Terraform (recommend using kubectl port-forward)."
  default     = "http://127.0.0.1:8200"
}

variable "vault_skip_child_token" {
  type        = bool
  description = "If true, the Vault provider will not attempt to create a limited child token (useful for CI tokens that cannot call auth/token/create)."
  default     = false
}

variable "kubernetes_auth_path" {
  type        = string
  description = "Mount path for the Kubernetes auth method (no leading/trailing slashes)."
  default     = "kubernetes"
}

variable "kubernetes_host" {
  type        = string
  description = "Kubernetes API host that Vault uses for TokenReview."
  # Matches the currently-configured value in-cluster (Kubernetes service cluster IP).
  # You can also use: https://kubernetes.default.svc:443
  default = "https://10.96.0.1:443"
}

variable "disable_iss_validation" {
  type        = bool
  description = "Matches the current working cluster behavior; set false if your issuer validation works."
  default     = true
}

variable "use_vault_local_sa_token" {
  type        = bool
  description = "If true, omit kubernetes_ca_cert/token_reviewer_jwt and let Vault use its in-cluster pod-local CA/JWT."
  default     = false
}

variable "kubernetes_ca_cert_pem" {
  type        = string
  description = "PEM-encoded Kubernetes CA cert used by Vault to validate the API server cert."
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = var.use_vault_local_sa_token || var.kubernetes_ca_cert_pem != null || var.kubernetes_ca_cert_file != null
    error_message = "Provide kubernetes_ca_cert_pem or kubernetes_ca_cert_file, or set use_vault_local_sa_token=true."
  }
}

variable "kubernetes_ca_cert_file" {
  type        = string
  description = "Path to a PEM-encoded Kubernetes CA cert file (alternative to kubernetes_ca_cert_pem)."
  default     = null
  nullable    = true
}

variable "token_reviewer_jwt" {
  type        = string
  description = "TokenReview JWT used by Vault's Kubernetes auth backend (sensitive; will end up in TF state)."
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = var.use_vault_local_sa_token || var.token_reviewer_jwt != null || var.token_reviewer_jwt_file != null
    error_message = "Provide token_reviewer_jwt or token_reviewer_jwt_file, or set use_vault_local_sa_token=true."
  }
}

variable "token_reviewer_jwt_file" {
  type        = string
  description = "Path to a file containing the TokenReview JWT (alternative to token_reviewer_jwt)."
  default     = null
  nullable    = true
}

variable "kv_mount_path" {
  type        = string
  description = "KV v2 mount path used by External Secrets (no leading/trailing slashes)."
  default     = "kv"
}

variable "external_secrets_policy_name" {
  type        = string
  description = "Vault policy name used by External Secrets."
  default     = "external-secrets"
}

variable "external_secrets_role_name" {
  type        = string
  description = "Vault Kubernetes auth role name used by External Secrets."
  default     = "external-secrets"
}

variable "external_secrets_role_bound_service_account_names" {
  type        = list(string)
  description = "Kubernetes service account names allowed to authenticate to the external-secrets role."
  default     = ["vault-auth", "platform-external-secrets"]
}

variable "external_secrets_role_bound_service_account_namespaces" {
  type        = list(string)
  description = "Kubernetes namespaces allowed to authenticate to the external-secrets role."
  default     = ["authentik", "argocd", "forgejo", "forgejo-runner", "longhorn-system", "vault", "oauth2-proxy", "external-secrets"]
}

variable "external_secrets_role_token_ttl_seconds" {
  type        = number
  description = "Token TTL for the external-secrets role."
  default     = 3600
}

variable "vault_bootstrap_policy_name" {
  type        = string
  description = "Name of the policy used for one-time bootstrap operations."
  default     = "vault-bootstrap"
}

variable "terraform_vault_policy_name" {
  type        = string
  description = "Name of the policy used by Terraform automation tokens."
  default     = "terraform-vault"
}

variable "oidc_auth_path" {
  type        = string
  description = "Mount path for the OIDC auth method (no leading/trailing slashes)."
  default     = "oidc"
}

variable "oidc_discovery_url" {
  type        = string
  description = "OIDC discovery URL for Authentik (issuer base URL)."
  default     = "https://authentik.k8s.magomago.moe/application/o/vault/"
}

variable "oidc_client_id" {
  type        = string
  description = "OIDC client ID registered in Authentik for Vault."
  default     = "vault"
}

variable "oidc_client_secret" {
  type        = string
  description = "OIDC client secret for Vault (sensitive; do not commit)."
  default     = null
  nullable    = true
  sensitive   = true
}

variable "oidc_default_role" {
  type        = string
  description = "Default OIDC role name in Vault."
  default     = "authentik"
}

variable "oidc_allowed_redirect_uris" {
  type        = list(string)
  description = "Allowed redirect URIs for the Vault OIDC role."
  default = [
    "https://vault.k8s.magomago.moe/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]
}

variable "oidc_bound_audiences" {
  type        = list(string)
  description = "Bound audiences for the Vault OIDC role."
  default     = ["vault"]
}

variable "oidc_user_claim" {
  type        = string
  description = "User claim to use as the Vault identity name."
  default     = "sub"
}

variable "oidc_scopes" {
  type        = list(string)
  description = "OIDC scopes requested by Vault."
  default     = ["openid", "profile", "email"]
}

variable "oidc_role_policies" {
  type        = list(string)
  description = "Vault policies attached to the default OIDC role."
  default     = ["default"]
}
