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

- RTL-SDR V4 plugged into thinkcentre2 (pve2) USB port
- LXC 210 provisioned via Terraform (privileged, for USB passthrough)

## Deploy

```bash
# If LXC doesn't exist
cd terraform && terraform apply -target=proxmox_virtual_environment_container.sdr

# If LXC already exists but isn't in Terraform state
cd terraform && terraform import proxmox_virtual_environment_container.sdr thinkcentre2/210

make sdr
```

`make sdr` runs three Ansible plays:
1. Adds USB cgroup passthrough rules to `/etc/pve/lxc/210.conf` on pve2 and restarts the LXC
2. Installs Docker and deploys trunk-recorder + rdio-scanner in the LXC
3. Deploys the Traefik route for `scanner.woodhead.tech`

## Verify

```bash
ssh -i ~/.ssh/id_ansible root@192.168.86.32 "docker ps"
ssh -i ~/.ssh/id_ansible root@192.168.86.32 "docker logs trunk-recorder --tail 10"
curl -I https://scanner.woodhead.tech  # expect 302 to auth.woodhead.tech
```

## Notes

- LXC must be privileged for USB passthrough — set in `terraform/lxc-sdr.tf`
- Re-run `make sdr` after LXC recreation to reapply USB cgroup rules
- Authentik: no separate application needed — domain-level `woodhead-forward-auth` covers all `*.woodhead.tech`
- Trunk Recorder typically decodes 4-10 SNO911 control channel messages/sec when the dongle is working
