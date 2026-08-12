#!/usr/bin/env bash
# Creates the AWS infrastructure, bootstraps the Kubernetes platform, and waits
# for the Secrets Manager -> External Secrets -> Grafana chain to become ready.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
git_root="$(git -C "$repo_root" rev-parse --show-toplevel)"
plan_file="$(mktemp "${TMPDIR:-/tmp}/aks-deployment.XXXXXX")"

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
  if [[ -n "$(git -C "$git_root" status --porcelain --untracked-files=normal -- 'AKS/*.tf' AKS/gitops AKS/helm-values AKS/scripts)" ]]; then
    echo "Deployment configuration has uncommitted changes." >&2
    echo "Commit and push them before deploying so Argo CD can read the same configuration." >&2
    exit 1
  fi

  current_branch="$(git -C "$git_root" branch --show-current)"
  if [[ "$current_branch" != "main" ]]; then
    echo "Argo CD tracks main, but the current branch is '$current_branch'." >&2
    echo "Merge the deployment configuration to main before deploying." >&2
    exit 1
  fi

  git -C "$git_root" fetch --quiet origin main
  if [[ "$(git -C "$git_root" rev-parse HEAD)" != "$(git -C "$git_root" rev-parse origin/main)" ]]; then
    echo "Local main does not match origin/main." >&2
    echo "Push or pull the GitOps configuration before deploying." >&2
    exit 1
  fi
fi

aws sts get-caller-identity >/dev/null

terraform -chdir="$repo_root" init -input=false
terraform -chdir="$repo_root" fmt -check -recursive
terraform -chdir="$repo_root" validate
terraform -chdir="$repo_root" plan -input=false -out="$plan_file"
terraform -chdir="$repo_root" apply -input=false "$plan_file"

"$repo_root/scripts/install-platform-addons.sh"

kubectl -n argocd wait --for=create application/root --timeout=2m
kubectl -n argocd wait --for=create application/external-secrets --timeout=5m
kubectl -n argocd wait \
  --for=jsonpath='{.status.health.status}'=Healthy \
  application/external-secrets \
  --timeout=10m
kubectl -n argocd wait --for=create application/platform-config --timeout=5m
kubectl -n argocd wait \
  --for=jsonpath='{.status.health.status}'=Healthy \
  application/platform-config \
  --timeout=10m
kubectl -n argocd wait --for=create application/monitoring-secrets --timeout=5m
kubectl -n monitoring wait \
  --for=condition=Ready \
  externalsecret/grafana-admin \
  --timeout=10m
kubectl -n argocd wait --for=create application/grafana --timeout=5m
kubectl -n argocd wait \
  --for=jsonpath='{.status.health.status}'=Healthy \
  application/grafana \
  --timeout=15m

echo "Deployment complete: EKS, platform controllers, External Secrets, and Grafana are healthy."
