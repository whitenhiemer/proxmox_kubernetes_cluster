---
sidebar_position: 2
title: Workloads
---

# Kubernetes Workloads

Manifests live in `k8s/base/`. Applied via `make k8s-base`.

## Base Manifests

```bash
make k8s-base          # Namespaces only
make k8s-base-metallb  # Namespaces + MetalLB IP pool
```

## Monitoring

After bootstrapping the cluster, deploy K8s exporters for Prometheus:

```bash
kubectl apply -f k8s/base/monitoring/kube-state-metrics.yml
kubectl apply -f k8s/base/monitoring/node-exporter-daemonset.yml
```

Then uncomment K8s scrape configs in `ansible/files/monitoring/prometheus/prometheus.yml` and restart Prometheus.

## Docker-Hosted Sites

The docs site, resume site, and landing page are currently deployed as Docker containers on the monitoring LXC (192.168.86.25) rather than as K8s workloads:

- `docs.woodhead.tech` -- Docusaurus static site (port 8081)
- `resume.woodhead.tech` -- Hugo static site (port 8082)
- `woodhead.tech` -- Landing page / service link tree (port 8083)

These could be migrated to K8s Deployments in the future if containerized workload management becomes a priority.
