# Architecture

```mermaid
flowchart TB
    User[Internet user]
    DNS[Route53 hosted zone<br/>ceedev.co.uk]
    ACM[ACM wildcard certificate<br/>*.ceedev.co.uk]

    subgraph AWS[AWS us-east-1]
        subgraph VPC[VPC 10.0.0.0/16]
            IGW[Internet Gateway]
            subgraph Public[Three public subnets]
                NLB[Internet-facing NLB<br/>Traefik Service ports 80/443]
            end
            subgraph Private[Three private subnets]
                EKS[EKS control plane and<br/>Auto Mode compute]
                Traefik[Traefik Pods x2<br/>entrypoints 8000/8443]
                App[NGINX test Pod<br/>planned]
                NAT[Three zonal NAT gateways<br/>regional migration paused]
            end
        end

        IRSA[OIDC provider and IRSA]
        CM[cert-manager<br/>deployed]
        ED[ExternalDNS<br/>planned]
    end

    User --> DNS
    DNS --> NLB
    ACM -. certificate used by .-> NLB
    NLB --> Traefik
    Traefik --> App
    App --> NAT --> IGW

    EKS --> Traefik
    IRSA --> CM
    IRSA --> ED
    CM -. DNS-01 records .-> DNS
    ED -. application DNS records .-> DNS
```

## Traffic and control flow

1. A user requests an application hostname such as `nginx.ceedev.co.uk`.
2. Route53 resolves the hostname to the NLB created for the Traefik Service.
3. The NLB forwards traffic to a healthy Traefik Pod in a private subnet.
4. Traefik matches the request against an IngressRoute and forwards it to the
   Kubernetes Service for the application.
5. The Service selects application Pods by label and forwards traffic to one
   of their Pod IPs.

The NGINX application path is planned but not deployed at the time this
document was written. The currently reachable platform component is Traefik.
