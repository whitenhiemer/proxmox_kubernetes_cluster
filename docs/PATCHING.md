# Patching Plan

Maintenance and update procedures for every component in the homelab.
Each section covers what to update, how to do it, and how to verify.

## Patching Schedule

| Cadence    | What                                             |
|------------|--------------------------------------------------|
| Weekly     | Debian LXC packages (`apt update && apt upgrade`) |
| Weekly     | Docker image pulls (ARR, monitoring stacks)       |
| Monthly    | Traefik binary update                             |
| Monthly    | Terraform provider update                         |
| Quarterly  | Talos + Kubernetes version bump                   |
| As-needed  | Proxmox VE host updates                           |
| Weekly     | Raspberry Pi packages (`apt update && apt upgrade`) |
| Automatic  | Home Assistant OTA updates (self-managed)          |
| Automatic  | TrueNAS Scale updates (self-managed via web UI)    |

---

## 1. Proxmox VE Hosts

Proxmox hosts use the no-subscription community repos (configured by `make setup`).

```bash
# On each Proxmox node (thinkcentre1, thinkcentre2, thinkcentre3)
ssh root@192.168.86.29  # or .30, .31

# Check available updates
apt update && apt list --upgradable

# Apply updates (schedule during maintenance window)
apt upgrade -y

# Reboot if kernel was updated
# WARNING: reboot one node at a time -- wait for Ceph to rebalance
pveversion  # check running version
reboot
```

**Verification**: `pveversion` on each node, check Ceph health with `ceph status`.

**Ceph-safe reboot order**:
1. Check `ceph status` -- must be HEALTH_OK
2. Set `ceph osd set noout` to prevent rebalance during reboot
3. Reboot one node
4. Wait for node to rejoin, verify `ceph status`
5. Repeat for next node
6. `ceph osd unset noout` when done

---

## 2. Debian LXC Containers

All LXC containers (Traefik, Recipe Site, ARR, Plex, Jellyfin, Monitoring, OpenClaw)
run Debian 12. System packages should be updated weekly.

### Ansible Playbook: `ansible/playbooks/patch-lxc.yml`

```bash
# Patch all LXC containers
cd ansible && ansible-playbook playbooks/patch-lxc.yml

# Patch a single container
cd ansible && ansible-playbook playbooks/patch-lxc.yml --limit traefik
```

**Verification**: `ssh root@<container-ip> "apt list --upgradable 2>/dev/null | wc -l"` should return 1 (header only).

---

## 3. Docker Compose Stacks

### ARR Stack (192.168.86.22)

```bash
ssh root@192.168.86.22

# Pull latest images
cd /opt/arr-stack && docker compose pull

# Recreate with new images (zero-downtime for independent services)
docker compose up -d

# Verify all containers healthy
docker compose ps

# Clean up old images
docker image prune -f
```

**Images**: Prowlarr, Sonarr, Radarr, Bazarr, Overseerr, SABnzbd, Gluetun.
All use `:latest` tags from linuxserver.io.

### Monitoring Stack (192.168.86.25)

```bash
ssh root@192.168.86.25
cd /opt/monitoring && docker compose pull && docker compose up -d
docker compose ps
docker image prune -f
```

**Images**: Prometheus, Grafana, Alertmanager, Node Exporter, cAdvisor,
Blackbox Exporter, PVE Exporter. All use `:latest`.

### OpenClaw (192.168.86.26)

OpenClaw is built from source -- no published image to pull.

```bash
ssh root@192.168.86.26
cd /opt/openclaw/src

# Pull latest source
git pull

# Rebuild image
docker build -t openclaw:local .

# Restart with new image
cd /opt/openclaw && docker compose up -d
docker image prune -f
```

### Ansible Playbook: `ansible/playbooks/patch-docker.yml`

```bash
# Update all Docker stacks
cd ansible && ansible-playbook playbooks/patch-docker.yml

# Update a single stack
cd ansible && ansible-playbook playbooks/patch-docker.yml --limit arr
```

---

## 4. Traefik Binary

Traefik runs as a native binary (not Docker) on the Traefik LXC.
Version is pinned in `ansible/playbooks/setup-traefik.yml`.

```bash
# 1. Update version in the playbook
#    Edit ansible/playbooks/setup-traefik.yml -- change traefik_version variable

# 2. Re-run the playbook (downloads new binary, restarts systemd service)
cd ansible && ansible-playbook playbooks/setup-traefik.yml

# 3. Verify
ssh root@192.168.86.20 "traefik version"
curl -sf https://recipes.woodhead.tech > /dev/null && echo "OK"
```

**Current version**: v3.2.0
**Release notes**: https://github.com/traefik/traefik/releases

---

## 5. Talos Linux + Kubernetes

Talos is immutable -- updates replace the entire OS image, not individual packages.
Kubernetes version is coupled to the Talos release.

### Talos Upgrade (rolling, non-destructive)

```bash
# 1. Update version pins
#    - terraform/terraform.tfvars: talos_version
#    - talos/talconfig.yaml: talosVersion, kubernetesVersion
#    - talos/patches/controlplane.yaml: installer image tag
#    - talos/patches/worker.yaml: installer image tag

# 2. Upgrade control plane first
export TALOSCONFIG=talos/_out/talosconfig
talosctl upgrade \
  --nodes 192.168.86.101 \
  --image ghcr.io/siderolabs/installer:v1.9.1

# 3. Wait for CP to come back, verify health
talosctl health --nodes 192.168.86.101

# 4. Upgrade workers one at a time
talosctl upgrade --nodes 192.168.86.111 --image ghcr.io/siderolabs/installer:v1.9.1
talosctl upgrade --nodes 192.168.86.112 --image ghcr.io/siderolabs/installer:v1.9.1

# 5. Verify cluster health
kubectl get nodes
talosctl health
```

### Kubernetes Upgrade (if upgrading K8s independently of Talos)

```bash
talosctl upgrade-k8s --to 1.32.0 --nodes 192.168.86.101
```

**Release notes**: https://www.talos.dev/latest/introduction/what-is-new/

---

## 6. Home Assistant OS

HAOS manages its own updates via the web UI. Do not patch via apt or Ansible.

```
Navigate to: https://home.woodhead.tech
Settings > System > Updates > Install
```

**Backup before updating**: Settings > System > Backups > Create Backup.
HAOS updates include the supervisor, core, and OS layers.

---

## 7. TrueNAS Scale

TrueNAS Scale manages its own updates via the web UI.

```
Navigate to: https://nas.woodhead.tech
System > Update > Check for Updates > Apply
```

**Before updating**: Create a manual checkpoint/snapshot of the boot pool.
TrueNAS supports rollback if an update breaks something.

---

## 8. Raspberry Pi Devices

The piboard Raspberry Pi runs Raspberry Pi OS and is patched separately from
the Proxmox-managed LXC containers.

### Ansible Playbook: `ansible/playbooks/patch-pi.yml`

```bash
# Patch all Raspberry Pi devices
make patch-pi

# Or run directly
cd ansible && ansible-playbook playbooks/patch-pi.yml
```

This runs `apt update && apt upgrade`, reboots if a kernel update requires it,
and cleans up old packages with `autoremove`.

**Verification**: `ssh bwoodwar@192.168.86.131 "apt list --upgradable 2>/dev/null | wc -l"` should return 1 (header only).

**Post-patch check**: Verify the piboard service is running after reboot:
```bash
ssh bwoodwar@192.168.86.131 "sudo systemctl status piboard"
curl http://192.168.86.131:8080/api/health
```

---

## 9. Kubernetes Manifests

In-cluster workloads (kube-state-metrics, node-exporter, MetalLB) are defined
in `k8s/base/`. Update image tags in the manifests, then reapply.

```bash
# Edit k8s/base/monitoring/kube-state-metrics.yml -- update image tag
# Edit k8s/base/monitoring/node-exporter-daemonset.yml -- update image tag

# Reapply
make k8s-base

# Verify
kubectl get pods -n monitoring
kubectl get pods -n metallb-system
```

**Current pins**:
- kube-state-metrics: `v2.13.0` (pinned)
- node-exporter: `latest` (should be pinned)

---

## 10. Terraform Provider

```bash
cd terraform

# Check current provider version
terraform version

# Update provider constraint in versions.tf if needed
# Then upgrade
terraform init -upgrade

# Plan to verify no breaking changes
terraform plan
```

**Current pin**: `bpg/proxmox ~> 0.66.0`
**Changelog**: https://github.com/bpg/terraform-provider-proxmox/releases

---

## Makefile Targets

```bash
make patch-proxmox   # apt update/upgrade on Proxmox hosts (serial, one at a time)
make patch-lxc       # apt update/upgrade on all LXC containers
make patch-docker    # docker compose pull + up -d on all Docker stacks
make patch-pi        # apt update/upgrade on Raspberry Pi devices (piboard, etc.)
```

---

## Version Pinning Policy

| Component           | Strategy       | Rationale                                      |
|---------------------|----------------|-------------------------------------------------|
| Docker images       | `:latest`      | Homelab -- favor freshness over stability       |
| Traefik binary      | Pinned (vX.Y.Z)| Reverse proxy is critical path, test before upgrading |
| Talos + K8s         | Pinned          | Cluster upgrades need deliberate rollout        |
| kube-state-metrics  | Pinned          | K8s manifests should be reproducible            |
| Terraform provider  | Range (`~>`)    | Allow patch updates, manual minor bumps         |
| Proxmox VE          | Community repo  | Follow Proxmox release cadence                  |
| Piboard binary      | Manual deploy   | Rebuild from source, deploy via `make deploy`    |
| HAOS / TrueNAS      | Self-managed    | Purpose-built OS with built-in update mechanisms |

---

## Rollback Procedures

### Docker Compose

```bash
# If a new image breaks a service, roll back to the previous image
ssh root@<container-ip>
cd /opt/<stack>

# Check what changed
docker compose logs <service> --tail 50

# Roll back by specifying previous image digest
docker compose down
docker pull <image>@sha256:<previous-digest>
docker tag <image>@sha256:<previous-digest> <image>:latest
docker compose up -d
```

### Traefik

```bash
# Previous binary is overwritten -- re-run playbook with old version
# Edit ansible/playbooks/setup-traefik.yml back to previous version
cd ansible && ansible-playbook playbooks/setup-traefik.yml
```

### Talos

```bash
# Talos supports rollback to previous OS image
talosctl rollback --nodes <node-ip>
```

### Proxmox

```bash
# If apt upgrade breaks something, Proxmox nodes can be restored
# from Ceph snapshots or PBS (Proxmox Backup Server) if configured.
# Rolling back individual packages:
apt install <package>=<previous-version>
```
