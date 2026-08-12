# EKS platform documentation

- [Traefik and Helm installation](traefik-and-helm.md)
- [Reusable deployment and destroy workflow](deployment.md)
- [GitOps workflow](gitops.md)
- [Networking](networking.md)
- [Architecture](architecture.md)

## Current deployment status

The EKS cluster, cert-manager, and Traefik are deployed. Traefik has two
healthy replicas and an internet-facing Network Load Balancer (NLB).

ExternalDNS, the Let's Encrypt `ClusterIssuer`, and the `nginx-test` workload
are defined in Terraform but have not yet been applied. Consequently,
`https://nginx.ceedev.co.uk` is the intended application address, not a live
website yet.
