# Traefik and Helm installation

## Ownership model

Terraform owns AWS infrastructure only. Helm is installed and run locally;
the `scripts/install-platform-addons.sh` script manages cert-manager,
ExternalDNS, Traefik, Prometheus, and Argo CD with `helm upgrade --install`.

```text
Terraform AWS outputs → local Helm CLI → Helm release → Kubernetes resources
```

This deliberately keeps Helm release records out of the Terraform backend.
Helm stores its release metadata in the Kubernetes cluster, while Terraform
continues to store only AWS infrastructure in its remote state. The values in
`helm-values/` are shared defaults; the script supplies the AWS-specific
values as Helm overrides.

## Bootstrap order

Some Kubernetes custom resources cannot be planned until their CRDs are
already registered in the API server. The safe first-install order is:

1. Apply Terraform to create or update the AWS infrastructure.
2. Run the local installer:

   ```bash
   ./scripts/install-platform-addons.sh
   ```

   The installer reads its AWS-specific values directly from Terraform
   outputs, configures `kubectl` for `aks-cluster`, installs cert-manager and
   its CRDs, applies the ClusterIssuer, then installs ExternalDNS, Traefik,
   Prometheus, and Argo CD. Finally, it applies the GitOps root Application. Set
   `CLUSTER_NAME` or `AWS_REGION` to override their defaults. Set
   `BOOTSTRAP_GITOPS=false` to skip the root Application.

The script is idempotent. Run it again to upgrade the pinned chart versions or
to reconcile their configuration.

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

The shared values also configure two replicas, a PodDisruptionBudget, rolling
updates, resource requests and limits, host-level topology spreading, JSON
logs, and non-root container security. The dashboard and metrics entrypoints
remain private. The AWS NLB terminates public TLS with the ACM certificate
whose ARN is supplied by the installer.

Because TLS terminates at the NLB, the NLB forwards plain TCP/HTTP to
Traefik's `websecure` backend port. Traefik TLS is therefore not enabled on
that entrypoint; enabling it as well would require the load balancer backend
protocol and certificate ownership model to be changed together.

To inspect the private dashboard, forward the management port directly from a
Traefik pod and open `http://127.0.0.1:9000/dashboard/`:

```bash
kubectl -n traefik port-forward deployment/traefik 9000:9000
```

### Install or upgrade Traefik only

The normal installation path is the platform installer described above. To
install or upgrade only Traefik, first configure `kubectl` for the cluster and
then run:

```bash
aws eks --region us-east-1 update-kubeconfig --name aks-cluster
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo update

acm_certificate_arn="$(terraform output -raw acm_certificate_arn)"

helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --version 29.0.1 \
  --values helm-values/traefik.yaml \
  --set-string "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert=${acm_certificate_arn}" \
  --atomic \
  --wait \
  --timeout 10m
```

Preview the generated Kubernetes resources without changing the cluster:

```bash
helm template traefik traefik/traefik \
  --namespace traefik \
  --version 29.0.1 \
  --values helm-values/traefik.yaml \
  --set-string "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert=arn:aws:acm:REGION:ACCOUNT:certificate/PLACEHOLDER"
```

## Operations

Check release and workload status:

```bash
helm -n cert-manager status cert-manager
helm -n traefik status traefik
helm -n monitoring status prometheus
helm -n argocd status argocd
kubectl -n cert-manager get pods
kubectl -n traefik rollout status deployment/traefik
kubectl -n traefik get pods,svc
kubectl -n monitoring get pods,svc,pvc
```

Use the installer for chart upgrades; do not add `helm_release` resources or a
Helm provider to Terraform.

## Migrating an existing Terraform-managed Helm installation

First run the local installer so the existing Helm releases are reconciled by
the CLI. Then remove only the former Helm and add-on entries from Terraform
state. This detaches them without uninstalling anything:

```bash
terraform state rm 'helm_release.cert_manager'
terraform state rm 'helm_release.external_dns'
terraform state rm 'helm_release.traefik'
terraform state rm 'kubernetes_namespace.cert_manager'
terraform state rm 'kubernetes_namespace.external_dns'
terraform state rm 'kubernetes_namespace.traefik'
terraform state rm 'kubernetes_manifest.letsencrypt_issuer'
```

Run `terraform state list` first. Addresses that are absent from the state do
not need a removal command. If the command returns no addresses, no state
migration is required.
