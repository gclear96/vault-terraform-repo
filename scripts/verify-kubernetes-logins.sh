#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?Set KUBECONFIG (e.g. ../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig)}"
: "${VAULT_ADDR:?Set VAULT_ADDR (e.g. http://127.0.0.1:8200)}"

ROLE="${ROLE:-external-secrets}"

verify_one() {
  local ns="$1"
  local sa="$2"

  local jwt
  jwt="$(kubectl -n "${ns}" create token "${sa}" --duration=10m)"

  curl -sf -X POST \
    -H 'Content-Type: application/json' \
    --data "$(jq -n --arg role "${ROLE}" --arg jwt "${jwt}" '{role:$role,jwt:$jwt}')" \
    "${VAULT_ADDR}/v1/auth/kubernetes/login" \
    | jq -er '.auth.client_token' >/dev/null

  echo "${ns}/${sa} OK"
}

verify_one authentik vault-auth
verify_one forgejo vault-auth
verify_one external-secrets platform-external-secrets
