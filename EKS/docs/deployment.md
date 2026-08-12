# Automated deployment and destroy workflow

Terraform owns AWS infrastructure. Helm bootstraps only Argo CD. Argo CD then
installs and owns all other Kubernetes controllers and workloads from `EKS/`.

## Prerequisites

- AWS credentials with permission to create the declared VPC, EKS, IAM,
  Route53, and Secrets Manager resources.
- The S3 backend bucket declared in `state.tf`.
- A public Route53 hosted zone matching `domain_name`.
- Terraform, AWS CLI, Helm, kubectl, and Git installed.
- All EKS deployment files committed and pushed to `origin/main`.

The state bucket and hosted zone are account bootstrap resources and are not
created by this stack.

## Local deployment

From the repository's `EKS` directory:

```bash
./scripts/deploy-platform.sh
```

The script verifies Git state and AWS authentication, runs Terraform init,
format validation, validation, plan, and apply, bootstraps Argo CD, applies the
root Application, and waits for the full platform to become healthy.

## GitHub Actions deployment

The root workflow `.github/workflows/eks-platform.yaml` validates Terraform and
renders the platform Helm charts on EKS pull requests and pushes. Deployment is
only performed through a manual workflow dispatch from `main` and requires the
`AWS_ROLE_TO_ASSUME` environment secret.

## Dependency chain

```text
Terraform: VPC → EKS Auto Mode → IAM/Pod Identity → Secrets Manager
                                      ↓
Bootstrap Helm:                     Argo CD
                                      ↓
Argo CD wave 0: Argo CD + cert-manager + External Secrets + gp3 storage
                                      ↓
Argo CD wave 1: ExternalDNS + Traefik + Prometheus + SecretStore
                                      ↓
Argo CD wave 2:       ClusterIssuer + Grafana ExternalSecret
                                      ↓
Argo CD wave 3:        Grafana + Argo route + nginx-test
```

## Destroy

Always review the destruction plan:

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

This removes Terraform-managed AWS resources. Argo-managed Kubernetes
resources disappear with the EKS cluster and are not individually stored in
Terraform state.
