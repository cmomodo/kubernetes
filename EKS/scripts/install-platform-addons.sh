#!/usr/bin/env bash
# Bootstraps Argo CD after Terraform creates the AWS infrastructure. Argo CD
# then installs and owns every remaining platform controller and workload.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap_gitops="${BOOTSTRAP_GITOPS:-true}"
argocd_chart_version="${ARGOCD_CHART_VERSION:-9.5.17}"

for command_name in aws helm kubectl terraform; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

terraform_output() {
  local output_name="$1"

  terraform -chdir="$repo_root" output -raw "$output_name" 2>/dev/null || {
    echo "Unable to read Terraform output: $output_name" >&2
    echo "Run 'terraform apply' first, or provide the matching environment variable." >&2
    return 1
  }
}

cluster_name="${CLUSTER_NAME:-$(terraform_output cluster_name)}"
aws_region="${AWS_REGION:-$(terraform_output aws_region)}"
domain_name="${DOMAIN_NAME:-$(terraform_output domain_name)}"

aws eks --region "$aws_region" update-kubeconfig --name "$cluster_name"

helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --namespace argocd \
  --create-namespace \
  --version "$argocd_chart_version" \
  --values "$repo_root/helm-values/argocd.yaml" \
  --set-string "global.domain=argocd.$domain_name" \
  --atomic \
  --wait \
  --timeout 10m

if [[ "$bootstrap_gitops" == "true" ]]; then
  kubectl apply -f "$repo_root/gitops/bootstrap/root-application.yaml"
fi

helm -n argocd status argocd
