---
sidebar_position: 7
title: Home Assistant
---

# Home Assistant

VM 301 | `192.168.86.41` | Port 8123 | `home.woodhead.tech`

Home Assistant OS (HAOS) VM for smart home automation.

## Deploy

```bash
make apply-homeassistant
```

Uses a pre-built HAOS qcow2 disk image (not ISO). Terraform downloads and imports it.

## Setup

1. Open Proxmox console -> VM 301, wait 2-3 min for initial boot
2. Access `http://192.168.86.41:8123`
3. Complete onboarding wizard
4. Set static IP: Settings > System > Network > `192.168.86.41/24`

## USB Passthrough

For Zigbee/Z-Wave dongles:

```bash
lsusb  # On Proxmox host, find vendor:product
qm set 301 -usb0 host=<vendor>:<product>
```

## Updates

HAOS manages its own updates. Back up before updating:
Settings > System > Backups > Create Backup, then Settings > System > Updates > Install.

## Integrations

- Alexa Media Player -- for Dexcom glucose voice announcements
- Webhook automations -- receives alerts from Alertmanager
- Zigbee2MQTT (MQTT broker at `192.168.86.36:1883`) -- Zigbee device integration
- Matter -- WiFi smart plug support via HAOS Matter Server addon

## Packages

HA configuration uses `homeassistant: packages: !include_dir_named packages` so
automation bundles can be deployed independently. Package files live in
`ansible/files/homeassistant/packages/` and are deployed via `make beardie`.

### Gutgrinda Skullkrumpa da Choppy

Bearded dragon enclosure automation (`packages/beardie.yaml`):

| Entity | ID |
|---|---|
| Temp/humidity | `sensor.0xa4c13874d0343902_temperature` / `_humidity` |
| Basking lamp | `switch.gutgrinda_basking_lamp` (Matter, plug `3016-351-2379`) |
| Ambient light | `switch.gutgrinda_ambient_light` (Matter, plug `2201-851-2373`) |

**Logic:**
- Basking lamp: on below 95°F / off above 110°F, daytime only (sun.sun condition), forced off at sunset
- Ambient light: on at sunrise+30min, off at sunset-30min (seasonal via HA sun integration)
- Alerts via Discord webhook (`!secret gutgrinda_discord_webhook`) for too hot (&gt;115°F), too cold (&lt;70°F), sensor offline

**Deploy:**
```bash
make beardie GUTGRINDA_DISCORD_WEBHOOK=<webhook_url> HA_TOKEN=<token>
```

Deploys via `qm guest exec` on VM 301 through Proxmox host `192.168.86.29` (HAOS SSH addon
cannot expose external ports). Writes package to `/mnt/data/supervisor/homeassistant/packages/`
and webhook URL to `secrets.yaml`.
