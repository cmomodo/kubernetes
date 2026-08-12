# Kubernetes Deployments

## Overview

Deployments provide declarative updates for Pods and ReplicaSets. They are one of the most commonly used workload resources in Kubernetes and are ideal for stateless applications.

## Key Features

- **Rolling Updates**: Update Pods in a controlled manner with zero downtime
- **Rollbacks**: Easily revert to previous versions if issues occur
- **Scaling**: Scale applications up or down as needed
- **Pause/Resume**: Temporarily halt rollout process for fixes

## Deployment Structure

A deployment configuration typically includes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  labels:
    app: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-container
          image: my-image:1.0
          ports:
            - containerPort: 80
```

## Common Deployment Commands

```bash
# Create a deployment
kubectl create -f deployment.yaml

# Get deployments
kubectl get deployments

# Update a deployment
kubectl apply -f updated-deployment.yaml

# Scale a deployment
kubectl scale deployment/my-deployment --replicas=5

# Rollback to previous version
kubectl rollout undo deployment/my-deployment

# View rollout history
kubectl rollout history deployment/my-deployment

# Delete a deployment
kubectl delete deployment my-deployment
```

## Best Practices

1. **Liveness and Readiness Probes**: Configure these to ensure proper health checks
2. **Resource Limits**: Set CPU and memory requests/limits
3. **Update Strategy**: Choose appropriate strategy based on application needs
4. **Labels and Annotations**: Use meaningful labels for better organization
5. **Deployment History**: Set an appropriate revision history limit

## Examples

The `deployment.yaml` and `deployment_task.yaml` files in this directory provide examples of Kubernetes deployment configurations.
