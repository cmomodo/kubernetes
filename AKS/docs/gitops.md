# GitOps workflow

Terraform bootstraps AWS infrastructure (EKS, IAM, Route53, and ACM). The
local Helm workflow installs shared platform controllers (cert-manager,
ExternalDNS, and Traefik). Argo CD owns the application resources under
`gitops/`.

## Bootstrap Argo CD

The Helm installer installs Argo CD and applies the root Application:

```bash
./scripts/install-platform-addons.sh
```

The root Application watches `gitops/applications` and creates the child
Applications. Manifest-based Applications then watch their workload
directories; this includes the Argo CD UI certificate and route under
`gitops/workloads/argocd`. The Grafana Application deploys its pinned Helm
chart with values from `helm-values/grafana.yaml`.

Grafana reads its admin credentials from the `grafana-admin` Secret in the
`monitoring` namespace. Provision that Secret with the `admin-user` and
`admin-password` keys through the cluster's secret-management workflow before
the first Grafana sync.

## Normal application changes

Edit the manifests under `gitops/workloads/`, commit the change, and push it
to `main`. Argo CD detects the Git change and synchronizes the cluster.

Check status with:

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application nginx-test
kubectl -n argocd describe application grafana
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
