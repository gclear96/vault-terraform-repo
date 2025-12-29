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

backend_args_common=(
  -backend-config="force_path_style=true"
  -backend-config="skip_credentials_validation=true"
  -backend-config="skip_requesting_account_id=true"
  -backend-config="skip_metadata_api_check=true"
  -backend-config="skip_region_validation=true"
)

try_init() {
  terraform init -input=false "$@"
}

if ! try_init -backend-config="endpoints.s3=${TF_S3_ENDPOINT}" "${backend_args_common[@]}" 2>out/tf-init-garage.err; then
  if grep -Eq "Invalid backend configuration argument|not expected" out/tf-init-garage.err; then
    echo "Terraform does not accept backend arg 'endpoints.s3'; retrying with 'endpoint='." >&2
    try_init -backend-config="endpoint=${TF_S3_ENDPOINT}" "${backend_args_common[@]}"
  else
    cat out/tf-init-garage.err >&2
    exit 1
  fi
fi
