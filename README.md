# Vault Terraform Repo (homelab)

Manages Vault configuration declaratively using the Terraform Vault provider.

## What this repo manages (minimum)

- Vault Kubernetes auth mount at `auth/kubernetes/`
- `auth/kubernetes/config`
  - `kubernetes_host` (currently `https://10.96.0.1:443`; `https://kubernetes.default.svc:443` is also valid)
  - `kubernetes_ca_cert` from the cluster CA (or let Vault use its in-cluster CA/JWT)
  - `token_reviewer_jwt` from a stable token source (or let Vault use its in-cluster SA JWT)
  - `disable_iss_validation=true` (matches the cluster’s current working setup)
- Policy `external-secrets` for KV v2 reads under `kv/`
- Policy `vault-bootstrap` (kept to reflect current instance; safe to remove later if unused)
- Role `external-secrets` bound to:
  - service accounts: `vault-auth`, `platform-external-secrets`
  - namespaces: `authentik`, `forgejo`, `external-secrets`
  - TTL: ~1h
- KV v2 secrets engine at `kv/`

## Security / state (important)

Terraform state will include **sensitive** fields if you provide them (notably `token_reviewer_jwt`, and potentially the Kubernetes CA cert depending on your inputs). Do **not** commit state or `*.tfvars`.

This repo uses an S3 backend (`backend.tf`) intended for an in-cluster S3-compatible store (Garage). Even with remote state, sensitive values can still end up in state, so treat state as a secret.

## Prereqs

- `terraform` (or `tofu`)
- `kubectl`
- `curl`
- `jq`
- Kubeconfig: `../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig`

## Terraform state backend (Garage / S3)

Garage runs in the `garage` namespace and exposes an in-cluster S3 API via Service `platform-garage` on port `3900`.

### One-time: create bucket + key (stores secret locally, gitignored)

This repo expects a bucket named `tf-state` and a key with read/write access.

Create them (no secrets printed to stdout; credentials are written to local gitignored files under `out/`):

```bash
export KUBECONFIG=../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig
./scripts/bootstrap-garage-tfstate.sh
```

Files created:

- `out/garage-tfstate-key.txt` (contains **secret key**; do not share/commit)
- `out/garage-tfstate.env` (convenience env file; do not share/commit)

### Local `terraform init` with port-forward

In one terminal:

```bash
export KUBECONFIG=../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig
./scripts/port-forward-garage-s3.sh
```

In another terminal:

```bash
source out/garage-tfstate.env
./scripts/tf-init-garage.sh
```

### CI `terraform init` (in-cluster runner)

Set these Forgejo repo secrets:

- `TF_S3_ENDPOINT` = `http://platform-garage.garage.svc:3900`
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` = the Garage key credentials

## Vault token requirements

The `VAULT_TOKEN` you use for Terraform must be able to:

- Enable/manage the Kubernetes auth mount (`sys/auth/*`)
- Write/read the Kubernetes auth config + role (`auth/kubernetes/*`)
- Write/read the `external-secrets` policy (`sys/policies/acl/*`)
- Manage the `kv/` mount (`sys/mounts/*`)

## Connect to Vault (port-forward)

In one terminal:

```bash
export KUBECONFIG=../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig
kubectl -n vault port-forward svc/platform-vault 8200:8200
```

In another terminal:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=...   # do not paste into chat or commit to git
```

Tip: if you want to avoid pasting tokens into your terminal history, store it locally in `out/vault.token` (gitignored) and do:

```bash
export VAULT_TOKEN="$(cat out/vault.token)"
```

## Inspect current Vault instance (recommended before Terraform)

```bash
export KUBECONFIG=../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig
./scripts/port-forward.sh
```

In a second terminal:

```bash
export KUBECONFIG=../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN="$(cat out/vault.token)"
./scripts/inspect-vault.sh
```

## Provide Kubernetes auth inputs (two options)

### Option A (explicit token reviewer JWT + CA cert)

This matches the current GitOps bootstrap job behavior and is fully explicit, but **stores `token_reviewer_jwt` in Terraform state**.

```bash
export KUBECONFIG=../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig

mkdir -p out
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > out/kubernetes-ca.crt
kubectl -n vault get secret platform-vault-tokenreview -o jsonpath='{.data.token}' | base64 -d > out/tokenreview.jwt

export TF_VAR_kubernetes_ca_cert_file=out/kubernetes-ca.crt
export TF_VAR_token_reviewer_jwt_file=out/tokenreview.jwt
```

### Option B (recommended when Vault runs in Kubernetes): let Vault use its pod-local CA/JWT

This avoids putting the reviewer JWT into Terraform state (Vault uses its own ServiceAccount token inside the pod).

```bash
export TF_VAR_use_vault_local_sa_token=true
```

This requires the Vault ServiceAccount to have TokenReview RBAC. Keep `talos-proxmox-platform-repo/clusters/homelab/bootstrap/rbac-vault-tokenreview.yaml` applied.

## Plan / apply (safe workflow)

Note: Your cluster already has these resources created by the temporary GitOps bootstrap Job. The safest way to transition to Terraform as the source of truth is to **import** existing Vault resources into Terraform state before your first apply.

Note: The first `terraform init` will download the Vault provider from the Terraform registry. In this environment, that may require explicit network approval.

```bash
./scripts/tf-init-garage.sh
terraform fmt
terraform validate
terraform plan
terraform apply
```

## CI/CD (Forgejo Actions)

This repo includes Forgejo Actions workflows under `.forgejo/workflows/`:

- `terraform.yml`: on PR → fmt/validate; on push to `main` → import + plan
- `apply.yml`: manual (`workflow_dispatch`) → import + apply

### Required Forgejo secrets

Set these repo secrets in Forgejo:

- `VAULT_ADDR` (example: `http://platform-vault.vault.svc:8200`)
- `VAULT_TOKEN` (use a scoped token; avoid long-lived root)
- `TF_VAR_token_reviewer_jwt` (sensitive; required to manage `auth/kubernetes/config`)
- `TF_VAR_kubernetes_ca_cert_pem` (sensitive; required to manage `auth/kubernetes/config`)

Note: until you deploy an in-cluster state backend (Garage/S3, etc.), the workflows intentionally rebuild local state each run by importing from the live Vault instance.

## Import existing resources (recommended)

Run from this repo directory after `terraform init`:

```bash
terraform import vault_auth_backend.kubernetes kubernetes
terraform import vault_kubernetes_auth_backend_config.this auth/kubernetes/config
terraform import vault_kubernetes_auth_backend_role.external_secrets auth/kubernetes/role/external-secrets
terraform import vault_policy.external_secrets external-secrets
terraform import vault_policy.vault_bootstrap vault-bootstrap
terraform import vault_mount.kv kv
```

If any import ID differs (provider/version differences), re-run `./scripts/inspect-vault.sh` and we’ll adjust.

## Helper scripts

Make them executable once:

```bash
chmod +x scripts/*.sh
```

- `scripts/port-forward.sh` starts the Vault port-forward
- `scripts/extract-auth-inputs.sh` writes CA/JWT files into `out/` (gitignored)
- `scripts/verify-kubernetes-logins.sh` performs read-only login checks for the three service accounts
- `scripts/inspect-vault.sh` prints a redacted summary of current Vault auth/mount/policy state

## Verification (read-only)

### 1) Verify Kubernetes login for each workload SA

Run each (token is short-lived; nothing is committed):

```bash
export KUBECONFIG=../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig
export VAULT_ADDR=http://127.0.0.1:8200

JWT="$(kubectl -n authentik create token vault-auth --duration=10m)"
curl -sf -X POST -H 'Content-Type: application/json' \
  --data "$(jq -n --arg role external-secrets --arg jwt "$JWT" '{role:$role,jwt:$jwt}')" \
  "$VAULT_ADDR/v1/auth/kubernetes/login" | jq -er '.auth.client_token' >/dev/null && echo "authentik/vault-auth OK"

JWT="$(kubectl -n forgejo create token vault-auth --duration=10m)"
curl -sf -X POST -H 'Content-Type: application/json' \
  --data "$(jq -n --arg role external-secrets --arg jwt "$JWT" '{role:$role,jwt:$jwt}')" \
  "$VAULT_ADDR/v1/auth/kubernetes/login" | jq -er '.auth.client_token' >/dev/null && echo "forgejo/vault-auth OK"

JWT="$(kubectl -n external-secrets create token platform-external-secrets --duration=10m)"
curl -sf -X POST -H 'Content-Type: application/json' \
  --data "$(jq -n --arg role external-secrets --arg jwt "$JWT" '{role:$role,jwt:$jwt}')" \
  "$VAULT_ADDR/v1/auth/kubernetes/login" | jq -er '.auth.client_token' >/dev/null && echo "external-secrets/platform-external-secrets OK"
```

### 2) Confirm External Secrets SecretStores are Ready

```bash
export KUBECONFIG=../talos-proxmox-bootstrap-repo/out/talos-admin-1.kubeconfig
kubectl get secretstores,clustersecretstores -A
```

## Cleanup plan (after Terraform is applied + verified)

Once the Terraform-managed config is stable and you’ve verified logins + SecretStores:

- Remove the temporary bootstrap Job manifest:
  - `talos-proxmox-platform-repo/clusters/homelab/bootstrap/vault-kubernetes-auth-bootstrap.yaml`
- Remove it from:
  - `talos-proxmox-platform-repo/clusters/homelab/bootstrap/kustomization.yaml`
    - remove the `- vault-kubernetes-auth-bootstrap.yaml` resource entry
- Keep TokenReview RBAC in place:
  - `talos-proxmox-platform-repo/clusters/homelab/bootstrap/rbac-vault-tokenreview.yaml`

Do not delete the Job until you’re confident Terraform is the source of truth for Vault auth configuration.
