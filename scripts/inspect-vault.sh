#!/usr/bin/env bash
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR (e.g. http://127.0.0.1:8200)}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN (do not commit tokens)}"

echo "== Vault health =="
curl -sf "${VAULT_ADDR}/v1/sys/health" | jq .

echo
echo "== Auth mounts =="
curl -sf -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/sys/auth" \
  | jq -r 'keys | sort | .[] | "- " + .'

echo
echo "== Secrets engines =="
curl -sf -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/sys/mounts" \
  | jq -r 'to_entries | sort_by(.key) | .[] | "- " + .key + " type=" + (.value.type // "n/a") + " options=" + ((.value.options // {})|tostring)'

echo
echo "== Policies =="
curl -sf -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/sys/policies/acl" \
  | jq -r '.data.policies | sort | .[] | "- " + .'

echo
echo "== Kubernetes auth config (sanitized) =="
curl -sf -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/auth/kubernetes/config" \
  | jq '{kubernetes_host: .data.kubernetes_host, disable_iss_validation: .data.disable_iss_validation, token_reviewer_jwt_set: .data.token_reviewer_jwt_set, kubernetes_ca_cert_set: ((.data.kubernetes_ca_cert // "") | tostring | length > 0)}'

echo
echo "== Kubernetes roles (list) =="
curl -sf -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/auth/kubernetes/role" \
  | jq -r '.data.keys | sort | .[] | "- " + .'

echo
echo "== Role external-secrets =="
curl -sf -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/auth/kubernetes/role/external-secrets" \
  | jq '{bound_service_account_names: .data.bound_service_account_names, bound_service_account_namespaces: .data.bound_service_account_namespaces, token_policies: .data.token_policies, token_ttl: .data.token_ttl}'

echo
echo "== Policy external-secrets (HCL) =="
curl -sf -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/sys/policies/acl/external-secrets" \
  | jq -r '.data.policy'

echo
echo "== Policy vault-bootstrap (HCL) =="
curl -sf -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/sys/policies/acl/vault-bootstrap" \
  | jq -r '.data.policy'

