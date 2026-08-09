#!/usr/bin/env bash
# Installs shared Kubernetes add-ons and bootstraps GitOps with the local Helm CLI.
# Helm release metadata stays in the Kubernetes cluster; it is not recorded in
# Terraform state. Terraform is used only to provision AWS infrastructure.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name="${CLUSTER_NAME:-aks-cluster}"
aws_region="${AWS_REGION:-us-east-1}"
bootstrap_gitops="${BOOTSTRAP_GITOPS:-true}"

cert_manager_chart_version="${CERT_MANAGER_CHART_VERSION:-1.15.3}"
external_dns_chart_version="${EXTERNAL_DNS_CHART_VERSION:-1.14.5}"
traefik_chart_version="${TRAEFIK_CHART_VERSION:-29.0.1}"
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

# Environment variables remain available as overrides, but the normal path is
# fully automatic after Terraform has created the AWS infrastructure.
acm_certificate_arn="${ACM_CERTIFICATE_ARN:-$(terraform_output acm_certificate_arn)}"
cert_manager_role_arn="${CERT_MANAGER_ROLE_ARN:-$(terraform_output cert_manager_role_arn)}"
domain_name="${DOMAIN_NAME:-$(terraform_output domain_name)}"
external_dns_role_arn="${EXTERNAL_DNS_ROLE_ARN:-$(terraform_output external_dns_role_arn)}"
route53_zone_id="${ROUTE53_ZONE_ID:-$(terraform_output route53_zone_id)}"

aws eks --region "$aws_region" update-kubeconfig --name "$cluster_name"

helm repo add jetstack https://charts.jetstack.io --force-update
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ --force-update
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "$cert_manager_chart_version" \
  --values "$repo_root/helm-values/cert-manager.yaml" \
  --set crds.enabled=true \
  --set-string "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$cert_manager_role_arn" \
  --atomic \
  --wait \
  --timeout 10m

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${domain_name}
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - dns01:
          route53:
            region: ${aws_region}
            hostedZoneID: ${route53_zone_id}
EOF

helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns \
  --create-namespace \
  --version "$external_dns_chart_version" \
  --values "$repo_root/helm-values/external_dns.yaml" \
  --set-string "domainFilters[0]=$domain_name" \
  --set-string "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$external_dns_role_arn" \
  --atomic \
  --wait \
  --timeout 10m

helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --version "$traefik_chart_version" \
  --values "$repo_root/helm-values/traefik.yaml" \
  --set-string "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert=$acm_certificate_arn" \
  --atomic \
  --wait \
  --timeout 10m

helm upgrade --install argocd argo/argo-cd \
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

helm list --all-namespaces
