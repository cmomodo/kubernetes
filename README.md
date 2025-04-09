# Kubernetes

Kubernetes is an open-source container orchestration platform designed to automate deploying, scaling, and operating application containers.

## Overview

Kubernetes, often abbreviated as K8s, provides a framework to run distributed systems resiliently. It takes care of scaling and failover for your applications, provides deployment patterns, and more.

## Core Components

- **Control Plane**: Brain of the Kubernetes cluster

  - API Server: Front-end for the Kubernetes control plane
  - etcd: Consistent and highly-available key-value store
  - Scheduler: Watches for newly created pods with no assigned node
  - Controller Manager: Runs controller processes
  - Cloud Controller Manager: Links cluster to cloud provider's API

- **Nodes**: Worker machines that run containerized applications
  - kubelet: Ensures containers are running in a Pod
  - kube-proxy: Network proxy that maintains network rules
  - Container Runtime: Software responsible for running containers

## Key Concepts

- **Pods**: Smallest deployable units that contain one or more containers
- **Services**: An abstract way to expose applications running on pods
- **ReplicaSets**: Ensures that a specified number of pod replicas are running
- **Deployments**: Provides declarative updates for Pods and ReplicaSets
- **Namespaces**: Virtual clusters within a physical cluster

## Getting Started

1. Install kubectl and a Kubernetes environment (Minikube, Docker Desktop, etc.)
2. Create deployments using YAML configuration files
3. Expose your applications with Services
4. Scale your applications as needed

## Useful Commands

```bash
kubectl get pods              # List all pods
kubectl create -f pod.yaml    # Create a resource from a file
kubectl apply -f deployment.yaml  # Apply a configuration to a resource
kubectl expose deployment     # Expose a deployment as a service
kubectl scale deployment      # Scale a deployment
```

## Additional Resources

- [Official Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Kubernetes GitHub Repository](https://github.com/kubernetes/kubernetes)
- [Interactive Kubernetes Tutorials](https://kubernetes.io/docs/tutorials/)
