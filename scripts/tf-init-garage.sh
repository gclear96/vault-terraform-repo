#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-out/garage-tfstate.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Create it first (see scripts/bootstrap-garage-tfstate.sh)." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

: "${TF_S3_ENDPOINT:?Missing TF_S3_ENDPOINT in ${ENV_FILE}}"
: "${AWS_ACCESS_KEY_ID:?Missing AWS_ACCESS_KEY_ID in ${ENV_FILE}}"
: "${AWS_SECRET_ACCESS_KEY:?Missing AWS_SECRET_ACCESS_KEY in ${ENV_FILE}}"

export TF_S3_ENDPOINT AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION

terraform init -input=false \
  -backend-config="endpoints.s3=${TF_S3_ENDPOINT}" \
  -backend-config="force_path_style=true" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_requesting_account_id=true" \
  -backend-config="skip_metadata_api_check=true" \
  -backend-config="skip_region_validation=true"
