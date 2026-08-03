# Traefik and Helm installation

## Ownership model

Terraform owns the Helm releases. The `helm_release` resources in `helm.tf`
render the YAML files in `helm-values/` and send the resulting values to the
Helm provider. Helm then creates and upgrades Kubernetes objects such as
Deployments, Services, ServiceAccounts, RBAC objects, CRDs, and ConfigMaps.

This provides one source of truth:

```text
Terraform configuration → rendered Helm values → Helm release → Kubernetes resources
```

The values files are templates, not standalone installs. For example,
`templatefile()` replaces `${acm_certificate_arn}` with the ACM certificate
ARN before the Traefik chart is installed. The ExternalDNS template similarly
receives the Route53 domain and its IAM role ARN.

## Bootstrap order

Some Kubernetes custom resources cannot be planned until their CRDs are
already registered in the API server. The safe first-install order is:

1. Apply `helm_release.cert_manager`. This installs cert-manager and its
   `Certificate` and `ClusterIssuer` CRDs.
2. Apply `helm_release.traefik`. This installs Traefik and its
   `IngressRoute` CRD.
3. Run the normal, full `terraform apply` after both CRD sets are visible.
   It can then create the `ClusterIssuer`, `Certificate`, IngressRoute,
   ExternalDNS release, and application resources.

The targeted bootstrap applies are only needed for the first installation or
to recover a missing CRD. Later changes should use a normal Terraform plan and
apply rather than `-target`.

## Cert-manager

The cert-manager Helm chart runs three controllers:

- `cert-manager` requests and renews certificates.
- `cert-manager-cainjector` injects CA bundles where needed.
- `cert-manager-webhook` validates cert-manager API requests.

The chart's `cert-manager` ServiceAccount is annotated with an IAM role ARN.
Using EKS IRSA, that exact ServiceAccount can assume a role with limited
Route53 permissions to write DNS-01 validation records. No static AWS key is
placed in a Pod.

## Traefik

The Traefik chart is installed in namespace `traefik` with two replicas. It
watches standard Kubernetes Ingress objects and Traefik `IngressRoute` CRDs.
Its Service is type `LoadBalancer`, which provisions an internet-facing AWS
NLB with IP targets.

Traefik runs as a non-root container, so its container entrypoints use ports
`8000` and `8443`. The Helm chart maps those to public Service ports `80` and
`443` using `exposedPort`:

```yaml
ports:
  web:
    port: 8000
    exposedPort: 80
  websecure:
    port: 8443
    exposedPort: 443
```

This separation prevents the `bind: permission denied` crash caused by trying
to listen directly on privileged ports 80 and 443.

## Operations

Check release and workload status:

```bash
helm -n cert-manager status cert-manager
helm -n traefik status traefik
kubectl -n cert-manager get pods
kubectl -n traefik rollout status deployment/traefik
kubectl -n traefik get pods,svc
```

Terraform normally performs Helm upgrades. The equivalent Helm action is an
`upgrade --install` using the rendered values, although it is intentionally
managed through Terraform rather than run manually.
