# Architecture

## EKS system design

![EKS system design](../eks-system-design.png)

```mermaid
flowchart TB
    User[Internet user] --> DNS[Route53]
    DNS --> NLB[EKS Auto Mode NLB]
    NLB --> Traefik[Traefik TLS termination]
    Traefik --> Apps[Argo CD / Grafana / nginx-test]

    Terraform --> VPC[VPC and subnets]
    Terraform --> EKS[EKS Auto Mode]
    Terraform --> Identity[EKS Pod Identity roles]
    Terraform --> SM[AWS Secrets Manager]

    Helm[Bootstrap Helm] --> Argo[Argo CD]
    Argo --> Controllers[cert-manager / ExternalDNS / Prometheus / ESO]
    Argo --> Traefik
    Argo --> Apps

    Identity --> Controllers
    ESO[External Secrets Operator] --> SM
    ESO --> GrafanaSecret[monitoring/grafana-admin]
    GrafanaSecret --> Apps
```

Terraform finishes AWS provisioning before Helm configures kubectl. The
bootstrap Argo CD release then reads the `EKS/gitops/applications` tree and
reconciles each child Application in sync-wave order.
