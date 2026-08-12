# Helm, Argo CD, and Traefik

## Bootstrap ownership

`scripts/install-platform-addons.sh` installs only Argo CD. It reads the EKS
cluster name, AWS region, and domain from Terraform outputs, configures
kubectl, installs the pinned Argo CD chart, and applies the root Application.

Argo CD then owns every chart under `gitops/applications/platform`. Re-running
the bootstrap script is safe for disaster recovery, while normal chart
upgrades are made by changing `targetRevision` or files under `helm-values/`.

## Traefik and TLS

Traefik is exposed through an EKS Auto Mode internet-facing Network Load
Balancer using TCP ports 80 and 443. TLS reaches Traefik unchanged and is
terminated using cert-manager-created Kubernetes TLS Secrets. ACM certificate
ARN injection is not required.

The public request path is:

```text
Route53 → Network Load Balancer → Traefik websecure → IngressRoute → Service
```

cert-manager and ExternalDNS receive Route53 permissions through
Terraform-managed EKS Pod Identity associations. No static AWS keys or IAM role
annotations are stored in Helm values.

## Operations

```bash
helm -n argocd status argocd
kubectl -n argocd get applications
kubectl -n cert-manager get pods
kubectl -n external-dns get pods
kubectl -n traefik get pods,svc
kubectl -n monitoring get pods
```
