#import from aws
data "aws_acm_certificate" "coderco_cert" {
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}