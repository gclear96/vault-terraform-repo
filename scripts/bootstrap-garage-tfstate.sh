#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-out}"
BUCKET="${BUCKET:-tf-state}"
KEY_NAME="${KEY_NAME:-terraform-tfstate}"

NAMESPACE="${NAMESPACE:-garage}"
POD="${POD:-platform-garage-0}"
CONTAINER="${CONTAINER:-garage}"

mkdir -p "${OUT_DIR}"
chmod 700 "${OUT_DIR}"

echo "Creating bucket ${BUCKET} (ignore errors if it already exists)..."
kubectl -n "${NAMESPACE}" exec "${POD}" -c "${CONTAINER}" -- /garage bucket create "${BUCKET}" || true

KEY_OUT="${OUT_DIR}/garage-tfstate-key.txt"
if [[ -f "${KEY_OUT}" ]]; then
  echo "Key output file already exists at ${KEY_OUT}; not overwriting."
else
  echo "Creating Garage key ${KEY_NAME} (writing secret to ${KEY_OUT})..."
  kubectl -n "${NAMESPACE}" exec "${POD}" -c "${CONTAINER}" -- /garage key create "${KEY_NAME}" >"${KEY_OUT}"
  chmod 600 "${KEY_OUT}"
fi

KEY_ID="$(awk -F': ' '/Key ID/ {print $2}' "${KEY_OUT}" | tr -d '[:space:]' | head -n1)"
SECRET_KEY="$(awk -F': ' '/Secret key/ {print $2}' "${KEY_OUT}" | tr -d '[:space:]' | head -n1)"

if [[ -z "${KEY_ID}" || -z "${SECRET_KEY}" ]]; then
  echo "Failed to parse key id/secret from ${KEY_OUT}" >&2
  exit 1
fi

echo "Granting read/write on ${BUCKET} to ${KEY_ID}..."
kubectl -n "${NAMESPACE}" exec "${POD}" -c "${CONTAINER}" -- /garage bucket allow "${BUCKET}" --key "${KEY_ID}" --read --write

ENV_OUT="${OUT_DIR}/garage-tfstate.env"
if [[ -f "${ENV_OUT}" ]]; then
  echo "Env file already exists at ${ENV_OUT}; not overwriting."
else
  umask 077
  cat >"${ENV_OUT}" <<EOF
# Garage S3 credentials for Terraform state (DO NOT COMMIT)
AWS_ACCESS_KEY_ID=${KEY_ID}
AWS_SECRET_ACCESS_KEY=${SECRET_KEY}
AWS_REGION=garage
TF_S3_ENDPOINT=http://127.0.0.1:3900
TF_S3_BUCKET=${BUCKET}
EOF
  chmod 600 "${ENV_OUT}"
fi

echo "Done."
echo "- Key output: ${KEY_OUT}"
echo "- Env file:   ${ENV_OUT}"
echo "- Access key: ${KEY_ID}"
