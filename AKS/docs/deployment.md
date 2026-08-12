# Automated deployment and destroy workflow

Terraform owns the AWS infrastructure. The local Helm CLI installs the
bootstrap controllers, and Argo CD owns application resources under `gitops/`.

## Prerequisites

- AWS CLI credentials with access to create the declared VPC, EKS, IAM,
  Route53, ACM, and Secrets Manager resources.
- The S3 backend bucket declared in `state.tf`.
- A public Route53 hosted zone matching `domain_name`.
- Terraform, AWS CLI, Helm, kubectl, and Git installed locally.
- The deployment configuration committed and pushed to `origin/main`, because
  Argo CD reads manifests from that branch rather than the local checkout.

The state bucket and public hosted zone are account-level bootstrap resources;
they are intentionally not created by this stack.

## One-command deployment

After reviewing and pushing the configuration, run:

```bash
cd /Users/momodou/Documents/kubernetes/kubernetes/AKS
./scripts/deploy-platform.sh
```

The script performs the complete deployment sequence:

1. Verifies that deployment files are committed and local `main` matches
   `origin/main`.
2. Checks AWS authentication.
3. Runs Terraform init, formatting checks, validation, plan, and apply.
4. Reads runtime configuration from Terraform outputs.
5. Configures kubectl; installs cert-manager, ExternalDNS, Traefik, and Argo CD.
6. Bootstraps the Argo CD root Application.
7. Waits for External Secrets Operator, its AWS `ClusterSecretStore`, the
   Grafana `ExternalSecret`, and Grafana itself to become healthy.

The dependency chain is:

```text
VPC → EKS → IAM + Pod Identity + Secrets Manager + ACM
                             ↓
                  Local Helm CLI: bootstrap controllers
                             ↓
                         Argo CD
                             ↓
        External Secrets → SecretStore → Grafana secret
                             ↓
             Grafana + Certificates/IngressRoutes
```

To inspect the Terraform plan without deploying, run:

```bash
terraform init
terraform validate
terraform plan
```

The lower-level `scripts/install-platform-addons.sh` remains idempotent and can
be run after Terraform has applied when only bootstrap controllers need to be
reconciled. Normal application and External Secrets changes are made through
Git and synchronized by Argo CD.

## Destroy for a temporary shutdown

Preview the destruction first:

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
```

The destroy removes all resources tracked in Terraform state, including the
EKS cluster, VPC, NAT gateways, IAM roles, Pod Identity association, and
Secrets Manager secret. Argo-managed resources disappear with the cluster but
are not individually tracked by Terraform.

Only after reviewing the plan:

```bash
terraform apply destroy.tfplan
```

The next deployment is recreated with `./scripts/deploy-platform.sh`.
