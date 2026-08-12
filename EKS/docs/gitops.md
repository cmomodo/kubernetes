# GitOps workflow

The root Argo CD Application reads `EKS/gitops/applications` recursively from
the repository's `main` branch. Every child source and Helm values reference
also stays under `EKS/`; no `AKS/` repository paths are used.

## Ownership

- Terraform: VPC, EKS Auto Mode, IAM policies and EKS Pod Identity
  associations, Route53 zone lookup, and the Grafana AWS Secrets Manager value.
- Bootstrap Helm: the initial Argo CD release only.
- Argo CD: Argo CD day-2 configuration, cert-manager, ExternalDNS, Traefik,
  Prometheus, External Secrets Operator, the EKS Auto Mode `gp3` StorageClass,
  Grafana, and nginx-test.

Terraform associates controller ServiceAccounts with IAM roles through EKS
Pod Identity. GitOps therefore contains no AWS account IDs, role ARNs, access
keys, or certificate ARN placeholders.

## Secret flow

Terraform writes a JSON `grafana-admin` value to AWS Secrets Manager. External
Secrets Operator authenticates with EKS Pod Identity, reads that value through
the `aws-secrets-manager` ClusterSecretStore, and creates the
`monitoring/grafana-admin` Kubernetes Secret. Grafana starts after that chain.
Its chart also creates the Traefik Ingress, ExternalDNS hostname, and
cert-manager TLS certificate for `grafana.ceedev.co.uk`.

## Normal changes

Edit files under `EKS/gitops` or `EKS/helm-values`, commit, and push to `main`.
Argo CD detects and reconciles the change.

Useful checks:

```bash
kubectl -n argocd get applications
kubectl get clustersecretstore aws-secrets-manager
kubectl -n monitoring get externalsecret grafana-admin
kubectl -n monitoring get secret grafana-admin
```
