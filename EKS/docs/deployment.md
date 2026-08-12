# Reusable deployment and destroy workflow

Terraform owns the AWS infrastructure. The local Helm CLI owns shared platform
controllers, and Argo CD owns application resources under `gitops/`. Run
commands from the repository root:

```bash
cd /Users/momodou/Documents/kubernetes/kubernetes/AKS
aws eks --region us-east-1 update-kubeconfig --name aks-cluster
```

## Normal deployment

Always preview the change before applying it:

```bash
terraform init
terraform fmt
terraform validate
terraform plan -out=deployment.tfplan
terraform apply deployment.tfplan
```

The dependency chain is:

```text
VPC → EKS → IAM/IRSA + ACM certificate
                             ↓
                  Local Helm CLI: platform controllers
                             ↓
                         Argo CD
                             ↓
                  GitOps Applications
                             ↓
               Certificates/IngressRoutes
```

After Terraform completes, install every platform chart and bootstrap the
GitOps root Application with one command:

```bash
./scripts/install-platform-addons.sh
```

From that point, application changes are made in Git and synchronized by Argo
CD. See [GitOps workflow](gitops.md) for the application workflow and the
Terraform state migration step.

Helm chart changes do not require a Terraform apply. Re-run
`./scripts/install-platform-addons.sh`; it reads the required Terraform outputs
automatically.
Terraform plans should not contain Helm releases or Kubernetes add-on objects.

## Destroy for a temporary shutdown

Preview the destruction first:

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
```

The destroy removes all resources tracked in Terraform state, including the
EKS cluster, VPC, NAT gateways, load balancer, IAM roles, and platform
resources. Argo-managed application resources disappear with the cluster but
are not individually tracked by Terraform.

Only after reviewing the plan:

```bash
terraform apply destroy.tfplan
```

The next day, the normal deployment workflow recreates the environment from
the configuration.
