#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-garage}"
SERVICE="${SERVICE:-platform-garage}"
LOCAL_PORT="${LOCAL_PORT:-3900}"
REMOTE_PORT="${REMOTE_PORT:-3900}"

exec kubectl -n "${NAMESPACE}" port-forward "svc/${SERVICE}" "${LOCAL_PORT}:${REMOTE_PORT}"
