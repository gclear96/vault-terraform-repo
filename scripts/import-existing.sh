#!/usr/bin/env bash
set -euo pipefail

import_if_missing() {
  local addr="$1"
  local id="$2"

  if terraform state show -no-color "${addr}" >/dev/null 2>&1; then
    echo "Already in state: ${addr}"
    return 0
  fi

  echo "Importing: ${addr} <- ${id}"
  terraform import "${addr}" "${id}"
}

import_if_missing vault_auth_backend.kubernetes kubernetes
import_if_missing vault_kubernetes_auth_backend_config.this auth/kubernetes/config
import_if_missing vault_kubernetes_auth_backend_role.external_secrets auth/kubernetes/role/external-secrets
import_if_missing vault_policy.external_secrets external-secrets
import_if_missing vault_policy.vault_bootstrap vault-bootstrap
import_if_missing vault_mount.kv kv
