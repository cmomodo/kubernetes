#!/usr/bin/env bash
# Creates AWS infrastructure, bootstraps Argo CD, and verifies the full GitOps
# installation from platform controllers through application workloads.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
git_root="$(git -C "$repo_root" rev-parse --show-toplevel)"
plan_file="$(mktemp "${TMPDIR:-/tmp}/eks-deployment.XXXXXX")"

cleanup() {
  rm -f -- "$plan_file"
}
trap cleanup EXIT

for command_name in aws git helm kubectl terraform; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

if [[ "${SKIP_GITOPS_PREFLIGHT:-false}" != "true" ]]; then
  if [[ -n "$(git -C "$git_root" status --porcelain --untracked-files=normal -- 'EKS/*.tf' EKS/gitops EKS/helm-values EKS/scripts)" ]]; then
    echo "EKS deployment configuration has uncommitted changes." >&2
    echo "Commit and push them before deploying so Argo CD reads the same configuration." >&2
    exit 1
  fi

  current_branch="${GITHUB_REF_NAME:-$(git -C "$git_root" branch --show-current)}"
  if [[ "$current_branch" != "main" ]]; then
    echo "Argo CD tracks main, but the current branch is '$current_branch'." >&2
    echo "Merge the EKS deployment configuration to main before deploying." >&2
    exit 1
  fi

  git -C "$git_root" fetch --quiet origin main
  if [[ "$(git -C "$git_root" rev-parse HEAD)" != "$(git -C "$git_root" rev-parse origin/main)" ]]; then
    echo "Local main does not match origin/main." >&2
    echo "Push or pull the EKS configuration before deploying." >&2
    exit 1
  fi
fi

aws sts get-caller-identity >/dev/null

terraform -chdir="$repo_root" init -reconfigure -input=false
terraform -chdir="$repo_root" fmt -check -recursive
terraform -chdir="$repo_root" validate
terraform -chdir="$repo_root" plan -input=false -out="$plan_file"
terraform -chdir="$repo_root" apply -input=false "$plan_file"

"$repo_root/scripts/install-platform-addons.sh"

wait_for_application() {
  local application_name="$1"
  local timeout="${2:-15m}"

  kubectl -n argocd wait --for=create "application/$application_name" --timeout=5m
  kubectl -n argocd wait \
    --for=jsonpath='{.status.health.status}'=Healthy \
    "application/$application_name" \
    --timeout="$timeout"
}

kubectl -n argocd wait --for=create application/root --timeout=2m
wait_for_application argocd
wait_for_application cert-manager
wait_for_application external-secrets
wait_for_application storage-config
wait_for_application external-dns
wait_for_application traefik
wait_for_application prometheus 20m
wait_for_application platform-config
wait_for_application cluster-issuer
wait_for_application monitoring-secrets

kubectl get clustersecretstore aws-secrets-manager
kubectl -n monitoring wait \
  --for=condition=Ready \
  externalsecret/grafana-admin \
  --timeout=10m

wait_for_application grafana 20m
wait_for_application argocd-config
wait_for_application nginx-test

echo "Deployment complete: EKS infrastructure, platform controllers, secrets, monitoring, and workloads are healthy."
