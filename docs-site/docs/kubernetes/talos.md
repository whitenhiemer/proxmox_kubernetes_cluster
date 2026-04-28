---
sidebar_position: 1
title: Talos Linux
---

# Talos Kubernetes Cluster

API VIP: `192.168.86.100` | CP: `.101` (tower1) | Workers: `.111` (thinkcentre2), `.112` (thinkcentre3), `.113` (zotac)

Talos Linux is an immutable, API-driven Kubernetes OS. No SSH -- all management through `talosctl` and `kubectl`.

## Nodes

| Role | IP | VM ID | Host | Resources |
|---|---|---|---|---|
| Control Plane | 192.168.86.101 | 400 | tower1 | 2 cores, 4GB RAM, 50GB (Ceph) |
| Worker 0 | 192.168.86.111 | 410 | thinkcentre2 | 4 cores, 8GB RAM, 100GB (Ceph) |
| Worker 1 | 192.168.86.112 | 411 | thinkcentre3 | 4 cores, 8GB RAM, 100GB (Ceph) |
| Worker 2 | 192.168.86.113 | 412 | zotac | 4 cores, 8GB RAM, 100GB (Ceph) |

## Bootstrap

```bash
export CLUSTER_VIP="192.168.86.100"
export CONTROLPLANE_IPS="192.168.86.101"
export WORKER_IPS="192.168.86.111,192.168.86.112,192.168.86.113"
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
talosctl upgrade --nodes 192.168.86.101 --image ghcr.io/siderolabs/installer:v1.12.5
# Then workers one at a time
```
