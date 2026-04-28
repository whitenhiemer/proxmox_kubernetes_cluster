---
sidebar_position: 6
title: Patching
---

# Patching Plan

Maintenance and update procedures for every component in the homelab.

## Patching Schedule

| Cadence | What |
|---|---|
| Weekly | Debian LXC packages (`apt update && apt upgrade`) |
| Weekly | Docker image pulls (ARR, monitoring stacks) |
| Monthly | Traefik binary update |
| Monthly | Terraform provider update |
| Quarterly | Talos + Kubernetes version bump |
| As-needed | Proxmox VE host updates |
| Weekly | Raspberry Pi packages |
| Automatic | Home Assistant OTA updates |
| Automatic | TrueNAS Scale updates |

## Quick Patch Commands

```bash
make patch-proxmox   # Proxmox hosts (serial, one at a time)
make patch-lxc       # All LXC containers
make patch-docker    # Docker compose pull + up -d on all stacks
make patch-pi        # Raspberry Pi devices
```

---

## 1. Proxmox VE Hosts

```bash
ssh root@192.168.86.29  # or .30, .31
apt update && apt list --upgradable
apt upgrade -y
pveversion
```

**Ceph-safe reboot order:**
1. `ceph status` -- must be HEALTH_OK
2. `ceph osd set noout`
3. Reboot one node
4. Wait for rejoin, verify `ceph status`
5. Repeat for next node
6. `ceph osd unset noout`

---

## 2. Debian LXC Containers

```bash
make patch-lxc
# Or single container:
cd ansible && ansible-playbook playbooks/patch-lxc.yml --limit traefik
```

---

## 3. Docker Compose Stacks

### ARR Stack (192.168.86.22)

```bash
ssh root@192.168.86.22
cd /opt/arr-stack && docker compose pull && docker compose up -d
docker compose ps
docker image prune -f
```

### Monitoring Stack (192.168.86.25)

```bash
ssh root@192.168.86.25
cd /opt/monitoring && docker compose pull && docker compose up -d
docker image prune -f
```

---

## 4. Traefik Binary

Version pinned in `ansible/playbooks/setup-traefik.yml`. Update the variable, re-run:

```bash
cd ansible && ansible-playbook playbooks/setup-traefik.yml
ssh root@192.168.86.20 "traefik version"
```

---

## 5. Talos Linux + Kubernetes

```bash
# Upgrade control plane first
talosctl upgrade --nodes 192.168.86.101 --image ghcr.io/siderolabs/installer:v1.9.1

# Then workers one at a time
talosctl upgrade --nodes 192.168.86.111 --image ghcr.io/siderolabs/installer:v1.9.1
talosctl upgrade --nodes 192.168.86.112 --image ghcr.io/siderolabs/installer:v1.9.1

# Verify
kubectl get nodes
talosctl health
```

---

## 6. Home Assistant / TrueNAS

Both are self-managed via their web UIs. Back up before updating.

- HA: Settings > System > Updates > Install
- TrueNAS: System > Update > Check for Updates > Apply

---

## 7. Raspberry Pi Devices

```bash
make patch-pi
# Verify piboard after reboot:
ssh bwoodwar@192.168.86.131 "sudo systemctl status piboard"
```

---

## 8. Kubernetes Manifests

```bash
# Update image tags in k8s/base/ manifests, then:
make k8s-base
kubectl get pods -n monitoring
```

---

## 9. Terraform Provider

```bash
cd terraform
terraform init -upgrade
terraform plan  # Verify no breaking changes
```

---

## Version Pinning Policy

| Component | Strategy | Rationale |
|---|---|---|
| Docker images | `:latest` | Homelab -- favor freshness |
| Traefik binary | Pinned (vX.Y.Z) | Critical path, test before upgrade |
| Talos + K8s | Pinned | Deliberate rollout |
| Terraform provider | Range (`~>`) | Allow patch, manual minor |
| HAOS / TrueNAS | Self-managed | Built-in update mechanisms |

---

## Rollback

| Component | Procedure |
|---|---|
| Docker | Roll back to previous image digest, `docker tag`, `docker compose up -d` |
| Traefik | Edit version in playbook, re-run `setup-traefik.yml` |
| Talos | `talosctl rollback --nodes <ip>` |
| Proxmox | `apt install <package>=<previous-version>` |
