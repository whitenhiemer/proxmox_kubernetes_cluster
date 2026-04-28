---
sidebar_position: 2
title: Monitoring
---

# Monitoring Stack

LXC 205 | `192.168.86.25` | Prometheus :9090, Grafana :3000, Alertmanager :9093

## Components

| Service | Port | Purpose |
|---|---|---|
| Prometheus | 9090 | Metrics collection + TSDB (30-day retention) |
| Grafana | 3000 | Dashboards + visualization |
| Alertmanager | 9093 | Alert routing (Discord, Twilio SMS, HA Alexa) |
| Node Exporter | 9100 | Host metrics for the monitoring LXC |
| cAdvisor | 8080 | Docker container metrics |
| Blackbox Exporter | 9115 | HTTP/ICMP service probes |
| PVE Exporter | 9221 | Proxmox VE API metrics |
| NUT Exporter (tc3) | 9199 | UPS metrics for thinkcentre3 |
| NUT Exporter (tower1) | 9198 | UPS metrics for tower1 |
| NUT Exporter (zotac) | 9197 | UPS metrics for zotac |
| Dexcom Exporter | 9666 | Glucose CGM readings |
| Twilio Relay | 9667 | SMS webhook relay for glucose alerts |
| Docs Site | 8081 | Docusaurus static site (docs.woodhead.tech) |
| Resume Site | 8082 | Hugo static site (resume.woodhead.tech) |
| Landing Site | 8083 | Service link tree (woodhead.tech) |

## Deploy

```bash
make monitoring \
  DISCORD_WEBHOOK="..." \
  GRAFANA_PASSWORD="..." \
  PVE_USER=monitoring@pve \
  PVE_TOKEN_NAME=prometheus \
  PVE_TOKEN_VALUE="..."
```

## Dashboards

Auto-provisioned from `ansible/files/monitoring/grafana/dashboards/`:

- Proxmox VE (ID 10347)
- Docker Containers (ID 14282)
- Traefik 3.x (ID 17346)
- Blackbox Exporter (ID 7587)
- Dexcom Glucose (custom)
- Home (custom overview)

## Dexcom Glucose Monitoring

Python exporter polling Dexcom Share API every 5 minutes.

**Alert thresholds:**

| Alert | Threshold | Delay | Severity |
|---|---|---|---|
| GlucoseCriticalLow | < 55 mg/dL | Immediate | Critical |
| GlucoseLow | 55-70 mg/dL | 5 min | Warning |
| GlucoseHigh | > 250 mg/dL | 15 min | Warning |
| GlucoseCriticalHigh | > 350 mg/dL | 5 min | Critical |
| DexcomStaleReading | No data 15 min | 5 min | Warning |

**Status:** Built, blocked on Dexcom Share credentials + Twilio account.

## Verify

```bash
curl http://192.168.86.25:9090/-/healthy
curl http://192.168.86.25:3000/api/health
```
