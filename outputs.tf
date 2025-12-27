output "kubernetes_auth_backend_path" {
  value       = vault_auth_backend.kubernetes.path
  description = "Kubernetes auth mount path."
}

output "external_secrets_role_name" {
  value       = vault_kubernetes_auth_backend_role.external_secrets.role_name
  description = "Kubernetes auth role for External Secrets."
}

