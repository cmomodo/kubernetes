# GitOps workflow

Terraform bootstraps AWS infrastructure (EKS, IAM, EKS Pod Identity, Secrets
Manager, Route53, and ACM). The
local Helm workflow installs shared platform controllers (cert-manager,
ExternalDNS, and Traefik). Argo CD owns the application resources under
`gitops/`.

## Bootstrap Argo CD

The Helm installer installs Argo CD and applies the root Application:

```bash
./scripts/install-platform-addons.sh
```

The root Application watches `gitops/applications` recursively and creates the
child Applications in sync-wave order. External Secrets Operator is installed
first, followed by the AWS `ClusterSecretStore`, the Grafana `ExternalSecret`,
and finally Grafana. The operator receives AWS credentials through the EKS Pod
Identity association managed by Terraform; no account ID or role ARN is stored
in the GitOps manifests.

Grafana reads its admin credentials from the `grafana-admin` Secret in the
`monitoring` namespace. Terraform creates the source value in AWS Secrets
Manager, and External Secrets materializes its `admin-user` and
`admin-password` fields as the Kubernetes Secret.

## Normal application changes

Edit the manifests under `gitops/workloads/`, commit the change, and push it
to `main`. Argo CD detects the Git change and synchronizes the cluster.

Check status with:

```bash
kubectl -n argocd get applications
kubectl get clustersecretstore aws-secrets-manager
kubectl -n monitoring get externalsecret grafana-admin
kubectl -n monitoring get secret grafana-admin
```

Do not use `kubectl apply` or Terraform for resources owned by an Argo CD
Application. Git is the source of truth; `prune` removes resources deleted
from Git and `selfHeal` repairs manual drift.

## Migrating existing Terraform-managed resources

If the GitOps resources already exist in Terraform state, apply the Git
bootstrap manifest first. After confirming the Applications are healthy, remove
the old nginx objects from Terraform state so Terraform does not delete the
live resources:

```bash
terraform state rm 'kubernetes_namespace.nginx_test'
terraform state rm 'kubernetes_deployment.nginx_test'
terraform state rm 'kubernetes_service.nginx_test'
terraform state rm 'kubernetes_manifest.nginx_ingressroute'
terraform state rm 'kubernetes_manifest.nginx_certificate'
```

If any address is not present in state, Terraform will report that it was not
found; that is safe during a partially completed migration. The next Terraform
plan should no longer contain the nginx-test workload resources. Terraform
does not manage Helm releases.
