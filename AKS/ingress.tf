resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"

  # Wait until the cluster exists
  depends_on = [module.eks]

  set = [
    {
      name  = "service.type"
      value = "LoadBalancer" # on AWS this usually creates an ELB for public traffic
    }
  ]
}