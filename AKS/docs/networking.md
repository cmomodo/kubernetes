# Networking

## VPC layout

The VPC CIDR is `10.0.0.0/16` in `us-east-1`, distributed across three
Availability Zones.

| Subnet class | CIDRs | Purpose |
|---|---|---|
| Private | `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` | EKS Auto Mode nodes and Pod IP targets |
| Public | `10.0.101.0/24`, `10.0.102.0/24`, `10.0.103.0/24` | Internet Gateway path and public load balancers |

DNS support and DNS hostnames are enabled in the VPC. The EKS control plane
and EKS compute use the private subnets. The EKS API endpoint is currently
publicly reachable; restrict `endpoint_public_access_cidrs` before production.

## Internet paths

Inbound application traffic uses this path:

```text
Internet → Route53 record → internet-facing NLB → Traefik Service → Traefik Pod → Service → application Pod
```

The public subnet tag `kubernetes.io/role/elb` lets AWS place public load
balancers in the public subnets. The Traefik Service has annotations selecting
an internet-facing NLB and IP targets, so the NLB sends traffic to Pod IPs in
the private subnets.

Outbound traffic from private workloads uses a NAT gateway and the Internet
Gateway:

```text
private Pod/node → private route table → NAT gateway → Internet Gateway → Internet
```

## NAT status

The deployed VPC currently has three **zonal** NAT gateways, one in each
Availability Zone. This is the traditional high-availability layout: a
private subnet uses the NAT gateway in the same AZ.

AWS also supports a newer single **regional** NAT gateway that spans multiple
AZs. A conversion to that design is intentionally paused: it requires replacing
the VPC module's zonal NAT resources with a dedicated regional
`aws_nat_gateway` resource and changing private-subnet routes. Do not run a
full Terraform apply for that migration until its plan has been reviewed; the
previous plan would have removed two zonal NAT gateways without creating the
desired regional replacement.

## DNS and certificates

The Route53 hosted zone for `ceedev.co.uk` is read by Terraform. Terraform
creates an ACM certificate for both `ceedev.co.uk` and `*.ceedev.co.uk`, then
writes its DNS validation CNAME record to that hosted zone.

When applied, ExternalDNS watches annotated Ingress/IngressRoute resources
and creates the matching Route53 records. cert-manager uses its own limited
IRSA role to create temporary DNS-01 ACME validation records for certificates.

The intended application hostname is `nginx.ceedev.co.uk`. It will resolve
only after the ExternalDNS and NGINX resources have been applied.
