#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?Set KUBECONFIG (e.g. ../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig)}"

OUT_DIR="${OUT_DIR:-out}"
mkdir -p "${OUT_DIR}"

kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "${OUT_DIR}/kubernetes-ca.crt"
kubectl -n vault get secret platform-vault-tokenreview -o jsonpath='{.data.token}' | base64 -d > "${OUT_DIR}/tokenreview.jwt"

echo "Wrote:"
echo "  ${OUT_DIR}/kubernetes-ca.crt"
echo "  ${OUT_DIR}/tokenreview.jwt"
echo
echo "Next:"
echo "  export TF_VAR_kubernetes_ca_cert_file=${OUT_DIR}/kubernetes-ca.crt"
echo "  export TF_VAR_token_reviewer_jwt_file=${OUT_DIR}/tokenreview.jwt"

