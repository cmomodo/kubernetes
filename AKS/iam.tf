# IRSA roles for cert-manager and external-dns.
# Both roles use the cluster's OIDC provider so pods can assume them
# without static credentials.

data "aws_caller_identity" "current" {}

# ── cert-manager IRSA ────────────────────────────────────────────────────────

data "aws_iam_policy_document" "cert_manager_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:cert-manager:cert-manager"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cert_manager" {
  name               = "cert-manager-irsa"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume.json

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

data "aws_iam_policy_document" "cert_manager" {
  # Allows cert-manager to solve DNS-01 challenges against Route53.
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

# ── external-dns IRSA ─────────────────────────────────────────────────────────

data "aws_iam_policy_document" "external_dns_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "external-dns-irsa"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume.json

  tags = {
    Terraform   = "true"
    Environment = "dev"
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

# ── Outputs ───────────────────────────────────────────────────────────────────

output "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager IRSA"
  value       = aws_iam_role.cert_manager.arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for external-dns IRSA"
  value       = aws_iam_role.external_dns.arn
}
