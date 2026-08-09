# Route53 zone lookup + ACM wildcard certificate with DNS-01 validation.
# The zone must already exist in your AWS account.
# Set TF_VAR_domain_name or pass -var="domain_name=ceedev.co.uk" on apply.

variable "domain_name" {
  description = "Root domain managed in Route53 (e.g. ceedev.co.uk)"
  type        = string
  default     = "ceedev.co.uk"
}

# ── Route53 ───────────────────────────────────────────────────────────────────

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

# ── ACM wildcard certificate ──────────────────────────────────────────────────

resource "aws_acm_certificate" "wildcard" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Write the DNS validation CNAME records into Route53 automatically.
resource "aws_route53_record" "cert_validation" {
  # ACM uses the same DNS validation CNAME for the apex domain and its wildcard
  # SAN. Manage it once, keyed by the wildcard entry, to avoid duplicate
  # Route53 record creation.
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
    if dvo.domain_name == "*.${var.domain_name}"
  }

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.this.zone_id
}

output "acm_certificate_arn" {
  description = "ARN of the validated ACM wildcard certificate"
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}

output "domain_name" {
  description = "Root domain used by the Kubernetes platform"
  value       = var.domain_name
}
