---
sidebar_position: 3
title: Roadmap
---

# Roadmap

Implementation priority and planned services for the homelab.

## Status

| # | Service | Status |
|---|---|---|
| 1 | NAS (TrueNAS Scale) | DONE |
| 2 | Proxmox Backups | DONE |
| 3 | ARR Stack | DONE |
| 4 | Plex / Jellyfin | DONE |
| 5 | Home Assistant | DONE |
| 6 | Authentik SSO | DONE |
| 7 | WireGuard VPN | DONE |
| 8 | Resource Balancing | DONE |
| 9 | Piboard Dashboard | DONE |
| 10 | Klipper 3D Printing | IN PROGRESS |
| 11 | Talos K8s Cluster | DONE |
| 12 | SDR Scanner | DONE |
| 13 | Dexcom Glucose Monitoring | IN PROGRESS |
| 14 | Docusaurus Docs Site | IN PROGRESS |
| 15 | Resume Site | PLANNED |

## IP Address Plan

| IP | Service | Type | VM ID |
|---|---|---|---|
| 192.168.86.1 | Gateway (Nest WiFi) | Router | -- |
| 192.168.86.29-31 | Proxmox nodes | Host | -- |
| 192.168.86.130 | tower1 (Proxmox node) | Host | -- |
| 192.168.86.20 | Traefik | LXC | 200 |
| 192.168.86.21 | Recipe site | LXC | 201 |
| 192.168.86.22 | ARR stack | LXC | 202 |
| 192.168.86.23 | Plex | LXC | 203 |
| 192.168.86.24 | Jellyfin | LXC | 204 |
| 192.168.86.25 | Monitoring | LXC | 205 |
| 192.168.86.26 | OpenClaw | LXC | 206 |
| 192.168.86.28 | Authelia | LXC | 207 |
| 192.168.86.32 | SDR Scanner | LXC | 210 |
| 192.168.86.39 | WireGuard VPN | LXC | 208 |
| 192.168.86.40 | TrueNAS | VM | 300 |
| 192.168.86.41 | Home Assistant | VM | 301 |
| 192.168.86.131 | Piboard dashboard | Pi | -- |
| 192.168.86.136 | Klipper Ender 5 Pro | Pi | -- |
| 192.168.86.138 | Klipper Ender 3 | Pi | -- |
| 192.168.86.100 | K8s API VIP | VIP | -- |
| 192.168.86.101 | K8s control plane | VM | 400 |
| 192.168.86.111-112 | K8s workers | VM | 410+ |
| 192.168.86.150-199 | MetalLB pool | K8s | -- |

## Planned Services

### Docusaurus Docs Site

- **Domain:** `docs.woodhead.tech`
- **Type:** K8s pod or Docker container
- **Purpose:** Centralized runbooks, architecture docs, and user guides
- **Stack:** Docusaurus (React + Markdown) -> nginx static serving

### Resume / Portfolio Site

- **Domain:** `resume.woodhead.tech`
- **Type:** Static site (Hugo or similar)
- **Purpose:** Personal resume and project portfolio

### Dexcom Glucose Monitoring

- **Status:** Code built, blocked on credentials
- **Stack:** Python exporter -> Prometheus -> Grafana dashboard
- **Alerts:** Twilio SMS + Home Assistant Alexa + Discord

### VLAN Segmentation (Deferred)

Requires replacing Google Nest WiFi with VLAN-aware APs.

| VLAN | Subnet | Purpose |
|---|---|---|
| 1 | 192.168.86.0/24 | Management |
| 10 | 10.0.10.0/24 | Trusted LAN |
| 20 | 10.0.20.0/24 | Servers |
| 30 | 10.0.30.0/24 | IoT |
| 40 | 10.0.40.0/24 | Guest WiFi |
