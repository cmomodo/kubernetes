# Kubernetes Services

## Overview

Services in Kubernetes are an abstract way to expose an application running on a set of Pods as a network service. They provide a consistent way to access your applications, regardless of where they are running in the cluster.

## Service Types

- **ClusterIP**: Exposes the service on an internal IP in the cluster (default)
- **NodePort**: Exposes the service on each Node's IP at a static port
- **LoadBalancer**: Exposes the service externally using a cloud provider's load balancer
- **ExternalName**: Maps the service to the contents of the externalName field

## Service Structure

A Service configuration typically includes:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: NodePort
  ports:
    - targetPort: 80 # Port on the pod where the app is listening
      port: 80 # Port on the service
      nodePort: 30080 # Port exposed on the node (30000-32767)
  selector:
    app: my-app # Label selector to identify the pods
```

## Common Service Commands

```bash
# Create a service
kubectl create -f service.yaml

# Create a service to expose a deployment
kubectl expose deployment my-deployment --port=80 --target-port=8080

# Get services
kubectl get services

# Describe a service
kubectl describe service my-service

# Delete a service
kubectl delete service my-service
```

## Service Discovery

Kubernetes offers two primary modes of service discovery:

1. **Environment Variables**: When a Pod starts, kubelet adds a set of environment variables for each active service
2. **DNS**: A cluster-aware DNS service (like CoreDNS) that watches the Kubernetes API for new Services

## Load Balancing

Services provide built-in load balancing capabilities:

- Round-robin distribution of network traffic
- Automatic reconfiguration when Pods change
- Health checking and removal of unhealthy endpoints

## Best Practices

1. **Use Meaningful Names**: Choose descriptive names for services
2. **Proper Selectors**: Ensure selectors match the intended pods
3. **Port Management**: Be consistent with port naming and numbering
4. **Headless Services**: Use when you need a service without load balancing
5. **External Traffic Policy**: Configure appropriately for your network requirements

## Example

The `main.yaml` file in this directory provides an example of a Kubernetes Service configuration.
