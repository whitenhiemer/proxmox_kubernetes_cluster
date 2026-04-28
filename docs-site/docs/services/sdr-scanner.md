---
sidebar_position: 5
title: SDR Scanner
---

# SDR Scanner

LXC 210 | `192.168.86.32` | Port 3000 | `scanner.woodhead.tech`

Decodes Snohomish County SNO911 P25 Phase II trunked radio using an RTL-SDR V4 USB dongle.

## Components

- **Trunk Recorder** -- P25 decoder using osmosdr driver
- **rdio-scanner** -- Web UI for browsing decoded radio traffic

## Prerequisites

- RTL-SDR V4 plugged into thinkcentre2 USB port
- LXC 210 created via Terraform (privileged, for USB passthrough)
- Kernel module `dvb_usb_rtl28xxu` blacklisted on thinkcentre2

## Deploy

```bash
cd terraform && terraform apply -target=proxmox_virtual_environment_container.sdr
make sdr
```

## Verify

```bash
ssh root@192.168.86.32 "docker ps"
ssh root@192.168.86.32 "docker logs trunk-recorder --tail 10"
curl -I https://scanner.woodhead.tech
```

## Notes

- LXC must be privileged for USB device passthrough
- If the LXC is recreated, re-run `make sdr` (re-applies USB cgroup rules + kernel module blacklist)
- Protected by Authentik SSO
