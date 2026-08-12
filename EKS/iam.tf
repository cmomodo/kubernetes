# EKS Pod Identity roles for controllers that access AWS APIs. EKS Auto Mode
# provides the Pod Identity agent, so no service-account role ARN annotations
# or static AWS credentials are required in Kubernetes manifests.

# ── cert-manager ─────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "cert_manager_assume" {
  statement {
    sid     = "AllowEksPodIdentity"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cert_manager" {
  name               = "cert-manager-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume.json

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "cert_manager" {
  statement {
    sid       = "GetChange"
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    sid = "UpsertRecords"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.this.zone_id}"]
  }

  statement {
    sid       = "ListZones"
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cert_manager" {
  name   = "cert-manager-route53"
  role   = aws_iam_role.cert_manager.id
  policy = data.aws_iam_policy_document.cert_manager.json
}

resource "aws_eks_pod_identity_association" "cert_manager" {
  cluster_name    = module.eks.cluster_name
  namespace       = "cert-manager"
  service_account = "cert-manager"
  role_arn        = aws_iam_role.cert_manager.arn
}

# ── external-dns ─────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "external_dns_assume" {
  statement {
    sid     = "AllowEksPodIdentity"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "external-dns-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume.json

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    sid       = "ChangeRecords"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.this.zone_id}"]
  }

  statement {
    sid = "ListZonesAndRecords"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "external_dns" {
  name   = "external-dns-route53"
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.external_dns.json
}

resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-dns"
  service_account = "external-dns"
  role_arn        = aws_iam_role.external_dns.arn
}

# ── external-secrets ─────────────────────────────────────────────────────────

data "aws_iam_policy_document" "external_secrets_assume" {
  statement {
    sid     = "AllowEksPodIdentity"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "external-secrets-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume.json

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid = "AllowSecretsManagerRead"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.grafana_admin.arn]
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "external-secrets-secretsmanager"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}

output "cert_manager_role_arn" {
  description = "IAM role ARN used by cert-manager EKS Pod Identity"
  value       = aws_iam_role.cert_manager.arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN used by external-dns EKS Pod Identity"
  value       = aws_iam_role.external_dns.arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by external-secrets EKS Pod Identity"
  value       = aws_iam_role.external_secrets.arn
}
