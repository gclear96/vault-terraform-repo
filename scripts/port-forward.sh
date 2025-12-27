#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?Set KUBECONFIG (e.g. ../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig)}"

kubectl -n vault port-forward svc/platform-vault 8200:8200

