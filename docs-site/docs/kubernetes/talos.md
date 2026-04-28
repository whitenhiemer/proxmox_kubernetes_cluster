---
sidebar_position: 1
title: Talos Linux
---

# Talos Kubernetes Cluster

API VIP: `192.168.86.100` | CP: `.101` | Workers: `.111`, `.112`

Talos Linux is an immutable, API-driven Kubernetes OS. No SSH -- all management through `talosctl` and `kubectl`.

## Nodes

| Role | IP | VM ID | Resources |
|---|---|---|---|
| Control Plane | 192.168.86.101 | 400 | 2 cores, 4GB RAM, 50GB (Ceph) |
| Worker 0 | 192.168.86.111 | 410 | 4 cores, 8GB RAM, 100GB (Ceph) |
| Worker 1 | 192.168.86.112 | 411 | 4 cores, 8GB RAM, 100GB (Ceph) |

## Bootstrap

```bash
export CLUSTER_VIP="192.168.86.100"
export CONTROLPLANE_IPS="192.168.86.101"
export WORKER_IPS="192.168.86.111,192.168.86.112"
make bootstrap
make kubeconfig
```

## Verify

```bash
export KUBECONFIG=talos/_out/kubeconfig
kubectl get nodes
talosctl --talosconfig talos/_out/talosconfig health
```

## Namespaces

- `ingress-system` -- Traefik / Ingress controllers
- `apps` -- Application workloads
- `monitoring` -- kube-state-metrics, node-exporter
- `metallb-system` -- MetalLB L2 load balancer

## MetalLB

L2 mode, IP pool: `192.168.86.150 - 192.168.86.199`

```bash
make k8s-base-metallb
```

## Upgrades

```bash
talosctl upgrade --nodes 192.168.86.101 --image ghcr.io/siderolabs/installer:v1.9.1
# Then workers one at a time
```
