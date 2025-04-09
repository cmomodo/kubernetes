# Kubernetes ReplicaSets

## Overview

ReplicaSets ensure that a specified number of pod replicas are running at any given time. They provide high availability by maintaining a stable set of replica pods and are the foundation of Deployments.

## Key Features

- **Pod Replication**: Maintain the specified number of pod replicas
- **Self-Healing**: Automatically replace pods that fail or are terminated
- **Horizontal Scaling**: Easily scale up or down based on demand
- **Pod Templates**: Define the pods to be created using pod templates

## ReplicaSet Structure

A ReplicaSet configuration typically includes:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: my-replicaset
  labels:
    app: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
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

## Common ReplicaSet Commands

```bash
# Create a ReplicaSet
kubectl create -f replicaset.yaml

# Get ReplicaSets
kubectl get replicasets

# Describe a ReplicaSet
kubectl describe replicaset my-replicaset

# Scale a ReplicaSet
kubectl scale replicaset my-replicaset --replicas=5

# Delete a ReplicaSet
kubectl delete replicaset my-replicaset
```

## ReplicaSets vs Deployments

While ReplicaSets ensure pod counts, Deployments provide higher-level management:

| Feature          | ReplicaSet | Deployment |
| ---------------- | ---------- | ---------- |
| Pod Replication  | ✓          | ✓          |
| Self-Healing     | ✓          | ✓          |
| Rolling Updates  | ✗          | ✓          |
| Rollbacks        | ✗          | ✓          |
| Revision History | ✗          | ✓          |

## Best Practices

1. **Use Deployments**: In most cases, use Deployments instead of directly managing ReplicaSets
2. **Labels**: Use clear and consistent labels for proper selection
3. **Pod Templates**: Define complete and valid pod templates
4. **Resource Limits**: Specify resource requests and limits for pods

## Examples

The `replicaset1.yaml` and `rc-definition.yaml` files in this directory provide examples of Kubernetes ReplicaSet configurations.
