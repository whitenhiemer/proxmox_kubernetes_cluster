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

## Future Workloads

The docs site and resume site are candidates for K8s Deployments once built:

- `docs.woodhead.tech` -- Docusaurus static site
- `resume.woodhead.tech` -- Resume/portfolio site

Both would use multi-stage Docker builds (node -> nginx) served via Traefik IngressRoute.
