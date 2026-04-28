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
