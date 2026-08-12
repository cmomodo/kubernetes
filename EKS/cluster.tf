module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.2"

  name               = var.cluster_name
  kubernetes_version = "1.33"

  endpoint_public_access = true
  # Restrict this to your IP/CIDR before production use (default is 0.0.0.0/0)
  # endpoint_public_access_cidrs = ["x.x.x.x/32"]

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # Wired from vpc.tf — created when you apply the VPC module
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "aws_region" {
  description = "AWS region containing the EKS cluster"
  value       = var.aws_region
}
