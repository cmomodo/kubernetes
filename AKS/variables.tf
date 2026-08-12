variable "aws_region" {
  description = "AWS region for the EKS platform"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "aks-cluster"
}

variable "environment" {
  description = "Environment tag applied to platform resources"
  type        = string
  default     = "dev"
}
