variable "vault_addr" {
  type        = string
  description = "Vault address for Terraform (recommend using kubectl port-forward)."
  default     = "http://127.0.0.1:8200"
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
  default     = ["authentik", "forgejo", "forgejo-runner", "external-secrets"]
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
