# Test nginx deployment + Traefik IngressRoute
# Verifies the full stack: NLB → Traefik → nginx → Route53 → TLS

# ── nginx namespace ───────────────────────────────────────────────────────────

resource "kubernetes_namespace" "nginx_test" {
  metadata { name = "nginx-test" }
}

# ── nginx Deployment ──────────────────────────────────────────────────────────

resource "kubernetes_deployment" "nginx_test" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace.nginx_test.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "nginx-test" }
    }

    template {
      metadata {
        labels = { app = "nginx-test" }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.27-alpine"

          port {
            container_port = 80
          }

          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }
        }
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# ── nginx Service ─────────────────────────────────────────────────────────────

resource "kubernetes_service" "nginx_test" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace.nginx_test.metadata[0].name
  }

  spec {
    selector = { app = "nginx-test" }

    port {
      port        = 80
      target_port = 80
    }
  }
}

# ── Traefik IngressRoute ──────────────────────────────────────────────────────
# Routes nginx.ceedev.co.uk → nginx-test service.
# Swap var.domain_name for your actual subdomain if needed.

resource "kubernetes_manifest" "nginx_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "nginx-test"
      namespace = kubernetes_namespace.nginx_test.metadata[0].name
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [{
        match = "Host(`nginx.${var.domain_name}`)"
        kind  = "Rule"
        services = [{
          name      = "nginx-test"
          namespace = kubernetes_namespace.nginx_test.metadata[0].name
          port      = 80
        }]
      }]
      tls = {
        secretName = "nginx-test-tls"
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# ── cert-manager Certificate for nginx subdomain ──────────────────────────────

resource "kubernetes_manifest" "nginx_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "nginx-test-tls"
      namespace = kubernetes_namespace.nginx_test.metadata[0].name
    }
    spec = {
      secretName = "nginx-test-tls"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = ["nginx.${var.domain_name}"]
    }
  }

  depends_on = [kubernetes_manifest.letsencrypt_issuer]
}
