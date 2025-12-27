#!/usr/bin/env bash
set -euo pipefail

terraform import vault_auth_backend.kubernetes kubernetes
terraform import vault_kubernetes_auth_backend_config.this auth/kubernetes/config
terraform import vault_kubernetes_auth_backend_role.external_secrets auth/kubernetes/role/external-secrets
terraform import vault_policy.external_secrets external-secrets
terraform import vault_policy.vault_bootstrap vault-bootstrap
terraform import vault_mount.kv kv

