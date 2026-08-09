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

The root Application watches `gitops/applications`. It creates the child
Applications, which then watch their workload directories. This includes the
Argo CD UI certificate and route under `gitops/workloads/argocd`.

## Normal application changes

Edit the manifests under `gitops/workloads/`, commit the change, and push it
to `main`. Argo CD detects the Git change and synchronizes the cluster.

Check status with:

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application nginx-test
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
