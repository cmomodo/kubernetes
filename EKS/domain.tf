# Route53 hosted zone lookup. TLS certificates are issued by cert-manager and
# terminated by Traefik, so no ACM certificate is required by this stack.

variable "domain_name" {
  description = "Root domain managed in Route53 (e.g. ceedev.co.uk)"
  type        = string
  default     = "ceedev.co.uk"
}

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.this.zone_id
}

output "domain_name" {
  description = "Root domain used by the Kubernetes platform"
  value       = var.domain_name
}
