#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
ENV_OUT="${ENV_OUT:-${OUT_DIR}/authentik.env}"
OVERWRITE="${OVERWRITE:-false}"
ALLOW_PARTIAL="${ALLOW_PARTIAL:-false}"

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 2
  fi
}

if [[ -f "${ENV_OUT}" && "${OVERWRITE}" != "true" ]]; then
  echo "Refusing to overwrite existing ${ENV_OUT}. Set OVERWRITE=true to replace it." >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
chmod 700 "${OUT_DIR}"

if [[ -z "${VAULT_ADDR:-}" ]]; then
  echo "Set VAULT_ADDR (for example: http://127.0.0.1:8200)." >&2
  exit 1
fi

if [[ -z "${VAULT_TOKEN:-}" ]]; then
  if [[ -f "${OUT_DIR}/vault.token" ]]; then
    VAULT_TOKEN="$(cat "${OUT_DIR}/vault.token")"
  else
    echo "Set VAULT_TOKEN or create ${OUT_DIR}/vault.token." >&2
    exit 1
  fi
fi

require_cmd jq
require_cmd curl

vault_get() {
  local path="$1"
  curl -fsS -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/${path}"
}

RESP="$(vault_get "kv/data/authentik/env")"

required_keys=(
  "AUTHENTIK_SECRET_KEY"
  "AUTHENTIK_POSTGRESQL__PASSWORD"
  "AUTHENTIK_OAUTH_GRAFANA_CLIENT_SECRET"
  "AUTHENTIK_OAUTH_ARGOCD_CLIENT_SECRET"
  "AUTHENTIK_OAUTH_FORGEJO_CLIENT_SECRET"
  "AUTHENTIK_OAUTH_LONGHORN_CLIENT_SECRET"
)

missing=()
declare -A values
for key in "${required_keys[@]}"; do
  val="$(jq -r --arg k "${key}" '.data.data[$k] // empty' <<<"${RESP}")"
  if [[ -z "${val}" ]]; then
    missing+=("${key}")
  else
    values["${key}"]="${val}"
  fi
done

if [[ "${#missing[@]}" -gt 0 && "${ALLOW_PARTIAL}" != "true" ]]; then
  echo "Missing keys in kv/authentik/env: ${missing[*]}" >&2
  echo "Set ALLOW_PARTIAL=true to generate a partial env file." >&2
  exit 1
fi

tmp="$(mktemp "${OUT_DIR}/.authentik.env.XXXXXX")"
chmod 600 "${tmp}"
{
  echo "# Authentik env secrets sourced from Vault (DO NOT COMMIT)"
  echo "TF_VAR_manage_authentik_env_secret=true"
  for key in "${required_keys[@]}"; do
    if [[ -n "${values[${key}]:-}" ]]; then
      case "${key}" in
        AUTHENTIK_SECRET_KEY)
          printf 'TF_VAR_authentik_secret_key=%q\n' "${values[${key}]}"
          ;;
        AUTHENTIK_POSTGRESQL__PASSWORD)
          printf 'TF_VAR_authentik_postgresql_password=%q\n' "${values[${key}]}"
          ;;
        AUTHENTIK_OAUTH_GRAFANA_CLIENT_SECRET)
          printf 'TF_VAR_authentik_oauth_grafana_client_secret=%q\n' "${values[${key}]}"
          ;;
        AUTHENTIK_OAUTH_ARGOCD_CLIENT_SECRET)
          printf 'TF_VAR_authentik_oauth_argocd_client_secret=%q\n' "${values[${key}]}"
          ;;
        AUTHENTIK_OAUTH_FORGEJO_CLIENT_SECRET)
          printf 'TF_VAR_authentik_oauth_forgejo_client_secret=%q\n' "${values[${key}]}"
          ;;
        AUTHENTIK_OAUTH_LONGHORN_CLIENT_SECRET)
          printf 'TF_VAR_authentik_oauth_longhorn_client_secret=%q\n' "${values[${key}]}"
          ;;
      esac
    fi
  done
} >"${tmp}"

mv "${tmp}" "${ENV_OUT}"
chmod 600 "${ENV_OUT}"
echo "Wrote ${ENV_OUT}"
