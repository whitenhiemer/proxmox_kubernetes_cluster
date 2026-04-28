---
slug: /
sidebar_position: 1
title: Overview
---

# woodhead.tech

Infrastructure documentation for the woodhead.tech Proxmox homelab.

## What's Here

- **[Architecture](/architecture)** -- Network topology, IP allocation, traffic flows, resource budgets, and service dependencies
- **[Runbook](/runbook)** -- Step-by-step deployment guide for every service from bare metal to running stack
- **[Patching](/patching)** -- Update procedures for Proxmox hosts, LXCs, Docker stacks, Kubernetes, and Raspberry Pi devices
- **[Roadmap](/roadmap)** -- Planned services, IP address plan, and implementation priority

## Quick Reference

| Resource | URL |
|----------|-----|
| Grafana | [grafana.woodhead.tech](https://grafana.woodhead.tech) |
| Home Assistant | [home.woodhead.tech](https://home.woodhead.tech) |
| Scanner | [scanner.woodhead.tech](https://scanner.woodhead.tech) |
| Proxmox | `https://192.168.86.29:8006` |
| Prometheus | [prometheus.woodhead.tech](https://prometheus.woodhead.tech) |

## Stack

```
Proxmox VE 8.x (4-node cluster, Ceph storage)
├── LXC Containers (Traefik, ARR, Monitoring, Authentik, WireGuard, SDR, ...)
├── VMs (TrueNAS, Home Assistant, Talos K8s cluster)
└── Standalone (Piboard Pi 3B, Klipper printers)
```

## Key Commands

```bash
make help          # Show all targets
make plan          # Terraform plan
make apply         # Terraform apply
make monitoring    # Deploy monitoring stack
make traefik       # Deploy Traefik
make patch-proxmox # Patch Proxmox hosts
make patch-lxc     # Patch all LXCs
make patch-docker  # Pull latest Docker images
```
