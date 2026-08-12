# Grafana admin credentials in AWS Secrets Manager.
# Consumed by external-secrets via the SecretStore.

resource "random_password" "grafana_admin" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "grafana_admin" {
  name                    = "grafana-admin"
  description             = "Grafana admin credentials for EKS cluster"
  recovery_window_in_days = 0

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id = aws_secretsmanager_secret.grafana_admin.id
  secret_string = jsonencode({
    admin-user     = "admin"
    admin-password = random_password.grafana_admin.result
  })
}

output "grafana_secret_arn" {
  description = "ARN of the Grafana admin secret in Secrets Manager"
  value       = aws_secretsmanager_secret.grafana_admin.arn
}
