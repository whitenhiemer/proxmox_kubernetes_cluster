---
sidebar_position: 8
title: Gutgrinda Enclosure
---

# Gutgrinda Skullkrumpa da Choppy — Enclosure Automation

Bearded dragon enclosure automation running as a Home Assistant package.

## Hardware

| Device | Model | Protocol | Entity |
|---|---|---|---|
| Temp/humidity sensor | ZG-227Z (`gutgrinda_enclosure`) | Zigbee → Z2M → MQTT | `sensor.0xa4c13874d0343902_temperature` |
| Basking lamp plug | Linkind LC09003256 (`3016-351-2379`) | Matter (WiFi) | `switch.gutgrinda_basking_lamp` |
| Ambient light plug | Linkind LC09003256 (`2201-851-2373`) | Matter (WiFi) | `switch.gutgrinda_ambient_light` |

## Automation Logic

```
Daytime (sunrise+30m → sunset):
  temp < 95°F  → basking lamp ON
  temp > 110°F → basking lamp OFF
  sunrise+30m  → ambient light ON
  sunset-30m   → ambient light OFF

Nighttime:
  sunset → basking lamp OFF (failsafe)

Anytime:
  temp > 115°F for 5min  → Discord alert: too hot
  temp < 70°F for 10min  → Discord alert: too cold
  sensor offline 15min   → Discord alert: sensor down
```

Thresholds are configurable at runtime via HA `input_number` helpers — no YAML edit required.

## Deploy

```bash
make beardie GUTGRINDA_DISCORD_WEBHOOK=<webhook_url> HA_TOKEN=<token>
```

`HA_TOKEN` is a long-lived access token from HA → Profile → Security → Long-lived access tokens.  
`GUTGRINDA_DISCORD_WEBHOOK` is the Discord channel webhook URL — written to HAOS `secrets.yaml` and never committed to git.

The Makefile target deploys via `qm guest exec` through the Proxmox host `192.168.86.29`, since the HAOS SSH addon cannot expose external ports (protected addon restriction). Files land at `/mnt/data/supervisor/homeassistant/packages/beardie.yaml`.

## Adding a New Device

1. **Zigbee device**: Enable permit_join via `switch.zigbee2mqtt_bridge_permit_join` in HA, put device in pairing mode, rename in Z2M UI (`192.168.86.36:8080`)
2. **Matter device**: Commission via HA Companion app (Settings → Devices → Add → Matter, scan QR code on plug sticker)

## Runbook

### Sensor shows unavailable
1. Check Z2M UI at `192.168.86.36:8080` — is `gutgrinda_enclosure` listed and online?
2. If offline, check the Zigbee2MQTT container: `ssh root@192.168.86.36 "docker ps"`
3. Replace battery in the ZG-227Z sensor (CR2032)

### Plug not responding
1. Check HA → Settings → Devices → Matter — is the device listed?
2. Power cycle the plug
3. If unavailable in HA, recommission: remove device from HA, factory reset plug (hold button >5s until red), re-pair via Companion app

### Redeploy after config changes
```bash
cd ~/Workspace/proxmox_kubernetes_cluster
make beardie HA_TOKEN=<token>
```

If the Discord webhook URL has not changed, `GUTGRINDA_DISCORD_WEBHOOK` can be omitted — the existing value in `secrets.yaml` is preserved.
