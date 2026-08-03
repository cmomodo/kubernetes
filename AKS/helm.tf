# Day-2 add-ons: cert-manager → external-dns → Traefik
# Install order matters: cert-manager CRDs must exist before Traefik tries to
# reference Certificate resources.

# ── Namespaces ────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "cert_manager" {
  metadata { name = "cert-manager" }
}

resource "kubernetes_namespace" "external_dns" {
  metadata { name = "external-dns" }
}

resource "kubernetes_namespace" "traefik" {
  metadata { name = "traefik" }
}

# ── cert-manager ──────────────────────────────────────────────────────────────

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.15.3"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  # Install CRDs as part of the Helm release so they are tracked.
  set {
    name  = "crds.enabled"
    value = "true"
  }

  values = [
    templatefile("${path.module}/helm-values/cert-manager.yaml", {
      cert_manager_role_arn = aws_iam_role.cert_manager.arn
    })
  ]

  depends_on = [module.eks]
}

# ClusterIssuer (Let's Encrypt production) — applied after cert-manager is ready.
resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "admin@${var.domain_name}"
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [{
          dns01 = {
            route53 = {
              region       = "us-east-1"
              hostedZoneID = data.aws_route53_zone.this.zone_id
            }
          }
        }]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# ── external-dns ──────────────────────────────────────────────────────────────

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.14.5"
  namespace  = kubernetes_namespace.external_dns.metadata[0].name

  values = [
    templatefile("${path.module}/helm-values/external_dns.yaml", {
      external_dns_role_arn = aws_iam_role.external_dns.arn
      domain_name           = var.domain_name
    })
  ]

  depends_on = [module.eks]
}

# ── Traefik ───────────────────────────────────────────────────────────────────

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "29.0.1"
  namespace  = kubernetes_namespace.traefik.metadata[0].name

  values = [
    templatefile("${path.module}/helm-values/traefik.yaml", {
      acm_certificate_arn = aws_acm_certificate_validation.wildcard.certificate_arn
    })
  ]

  # Traefik needs cert-manager CRDs to exist if using Certificate resources.
  depends_on = [helm_release.cert_manager]
}
