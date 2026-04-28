---
sidebar_position: 5
title: Deployment Runbook
---

# Deployment Runbook

Step-by-step guide to deploy the full Proxmox homelab infrastructure from scratch.

## Prerequisites

Install these on your local machine (Mac):

```bash
brew install terraform
brew install ansible
brew install siderolabs/tap/talosctl
brew install kubectl
brew install httpd  # Provides htpasswd
```

## Phase 0: Proxmox Base Setup

### 0.1 Install Proxmox VE

1. Download Proxmox VE 8.x ISO from proxmox.com
2. Flash to USB with `dd` or Balena Etcher
3. Install on each node (5 nodes)
4. Set static IPs during install:
   - Node 1: `192.168.86.29` (thinkcentre1)
   - Node 2: `192.168.86.30` (thinkcentre2)
   - Node 3: `192.168.86.31` (thinkcentre3)
   - Node 4: `192.168.86.130` (tower1)
   - Node 5: `192.168.86.147` (zotac)
5. Access web UI at `https://192.168.86.29:8006`

### 0.2 Create Proxmox Cluster

```bash
# On node 1
pvecm create homelab

# On node 2 (and 3)
pvecm add 192.168.86.29
```

### 0.3 Repository Setup

The `make setup` playbook switches from enterprise repos to free no-subscription community repos. Manual alternative:

```bash
rm /etc/apt/sources.list.d/pve-enterprise.list
rm /etc/apt/sources.list.d/ceph.list
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
echo "deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription" > /etc/apt/sources.list.d/ceph-no-subscription.list
apt update
```

### 0.4 Configure Ceph

Via Proxmox web UI (Datacenter > Ceph):
1. Install Ceph on each node
2. Create OSDs from available disks
3. Create pool `ceph-pool` (size 3 for 3 nodes, size 2 for 2 nodes)

```bash
ceph status
ceph osd pool ls  # Should show "ceph-pool"
```

### 0.5 Create API Token

Via Proxmox web UI: Datacenter > Permissions > API Tokens
- User: `root@pam`, Token ID: `terraform`
- Uncheck "Privilege Separation"
- Format: `root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 0.6 Run Base Setup Playbook

```bash
vim ansible/inventory/hosts.yml  # Update node IPs
make setup
```

---

## Phase 1: Cloudflare DNS + DDNS

### 1.1-1.5 Cloudflare Setup

1. Sign up at Cloudflare (free tier), add `woodhead.tech`
2. Point Squarespace nameservers to Cloudflare
3. Add A records: `woodhead.tech` and `*.woodhead.tech` -> public IP (DNS only, 5 min TTL)
4. Create API token: Edit zone DNS permission for `woodhead.tech`
5. Note Zone ID from the overview page

### 1.6-1.7 Deploy DDNS

```bash
cp scripts/ddns/cloudflare.env.example scripts/ddns/cloudflare.env
vim scripts/ddns/cloudflare.env  # CF_API_TOKEN, CF_ZONE_ID, CF_RECORD_NAMES
make ddns
```

Verify:
```bash
ssh root@192.168.86.29 "journalctl -t cloudflare-ddns --no-pager -n 20"
```

---

## Phase 2: Terraform

### 2.1 Configure

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars
```

### 2.2-2.3 Apply

```bash
make prepare         # Download Talos ISO
make prepare-truenas # Download TrueNAS ISO
make init            # Download providers
make plan            # Review changes
make apply           # Create everything
```

---

## Phase 3: Traefik Reverse Proxy

```bash
htpasswd -nb admin your-secure-password-here
# Update ansible/files/traefik/dynamic/dashboard.yml with the hash (double $$ signs)

make traefik
```

Configure port forwarding in Google Home app:
- Port 80 -> `192.168.86.20:80`
- Port 443 -> `192.168.86.20:443`

---

## Phase 4: Recipe Site

```bash
make recipe-site
curl https://recipes.woodhead.tech
```

---

## Phase 5: TrueNAS Scale NAS

1. Install TrueNAS via Proxmox console (VM 300) -- install to `/dev/sda`
2. Verify: `curl http://192.168.86.40/api/v2.0/system/info`
3. Run Ansible: `make truenas TRUENAS_PASSWORD=<password>`
4. Add NFS storage in Proxmox: `truenas-backups` and `truenas-isos`
5. Create backup job: Datacenter > Backup > Add (nightly 02:00, snapshot, LZO)

---

## Phase 6: ARR Media Stack

```bash
# Without NFS
make arr-stack

# With NFS from TrueNAS
cd ansible && ansible-playbook playbooks/setup-arr-stack.yml \
  --extra-vars "nfs_server=192.168.86.40 nfs_share=/mnt/tank/media"
```

Configure services in order: Prowlarr -> SABnzbd -> Sonarr -> Radarr -> Bazarr -> Overseerr -> Gluetun

---

## Phase 7: Plex and Jellyfin

```bash
make plex
make jellyfin
```

Both share iGPU (`/dev/dri`) for hardware transcoding. Must run on the same Proxmox node.

---

## Phase 8: Home Assistant

```bash
make apply-homeassistant  # Downloads HAOS image + creates VM
```

1. Open Proxmox console -> VM 301, wait 2-3 min
2. Access `http://192.168.86.41:8123`, complete onboarding
3. Set static IP: Settings > System > Network

---

## Phase 9: Kubernetes Cluster

```bash
export CLUSTER_VIP="192.168.86.100"
export CONTROLPLANE_IPS="192.168.86.101"
export WORKER_IPS="192.168.86.111,192.168.86.112,192.168.86.113"
make bootstrap
make kubeconfig
kubectl get nodes  # Should show 4 nodes Ready
make k8s-base-metallb
```

---

## Phase 10: Monitoring Stack

### 10.1-10.4 Deploy

1. Create PVE read-only API token (monitoring@pve, PVEAuditor role)
2. Create Discord webhook in `#homelab-alerts` channel

```bash
make monitoring \
  DISCORD_WEBHOOK="https://discord.com/api/webhooks/..." \
  GRAFANA_PASSWORD="your-password" \
  PVE_USER=monitoring@pve \
  PVE_TOKEN_NAME=prometheus \
  PVE_TOKEN_VALUE="..."
```

### 10.5-10.9 Post-Deploy

```bash
make traefik  # Enable Prometheus metrics entrypoint

# Verify
curl http://192.168.86.25:9090/-/healthy
curl http://192.168.86.25:3000/api/health
```

### 10.10 Dexcom Glucose Monitoring

:::info Blocked
Requires wife's Dexcom Share credentials and Twilio account setup.
:::

```bash
make monitoring \
  DEXCOM_USERNAME=... \
  DEXCOM_PASSWORD=...
```

Alert thresholds:

| Alert | Threshold | Delay | Severity |
|---|---|---|---|
| GlucoseCriticalLow | < 55 mg/dL | Immediate | Critical |
| GlucoseLow | 55-70 mg/dL | 5 min | Warning |
| GlucoseHigh | > 250 mg/dL | 15 min | Warning |
| GlucoseCriticalHigh | > 350 mg/dL | 5 min | Critical |
| DexcomStaleReading | No data 15 min | 5 min | Warning |

---

## Phase 10b: SDR Scanner

```bash
cd terraform && terraform apply -target=proxmox_virtual_environment_container.sdr
make sdr
```

Verify:
```bash
ssh root@192.168.86.32 "docker ps"
curl -I https://scanner.woodhead.tech
```

---

## Phase 11: Authentik Identity Provider

```bash
make authentik
```

Access `http://192.168.86.28:9000`, configure admin account and TOTP.

---

## Phase 12: WireGuard VPN

```bash
make wireguard
```

Forward UDP 51820 in Google Home app -> `192.168.86.39:51820`.
Import client configs from `ansible/files/wireguard/clients/`.

---

## Phase 13: Libby Alert

```bash
# Set SSH hookscript (required for Debian 12.12)
ssh root@192.168.86.29 "chmod +x /var/lib/vz/snippets/lxc-ssh-fix.sh && pct set 209 --hookscript local:snippets/lxc-ssh-fix.sh && pct reboot 209"

make libby-alert \
  TWILIO_ACCOUNT_SID="..." \
  TWILIO_AUTH_TOKEN="..." \
  TWILIO_FROM="..." \
  TWILIO_TO="..." \
  DISCORD_WEBHOOK="..."
```

---

## Phase 14: Piboard Dashboard

1. Flash Raspberry Pi OS Lite to SD card, enable SSH + WiFi
2. Build and deploy:

```bash
cd piboard
make build-pi
make deploy PI_HOST=192.168.86.131
ssh bwoodwar@192.168.86.131 "sudo bash /tmp/deploy/setup-pi.sh"
```

---

## Phase 15: Security Hardening

```bash
make harden  # Disables SSH password auth, installs fail2ban
```

---

## Day-2 Operations

### Adding a New LXC Service

1. `terraform/lxc-<service>.tf` + variables
2. `ansible/files/traefik/dynamic/<service>.yml` (Traefik route)
3. `ansible/playbooks/setup-<service>.yml`
4. Add host to `ansible/inventory/hosts.yml`
5. `make apply && make traefik`

### Troubleshooting

| Problem | Fix |
|---|---|
| Terraform can't connect | Verify API token, check `proxmox_insecure = true` |
| DDNS not updating | Check cron + logs on 192.168.86.29 |
| Traefik no certs | Verify CF API token permissions (Zone:DNS:Edit) |
| SSH refused on new LXC | Debian 12.12 IPv6-only binding -- run `pct exec` fix or reboot with hookscript |
| Stale ARP entry | `ip neigh del <ip> dev vmbr0 && ping -c1 <ip>` on Proxmox host |
| Authentik Bad Gateway | Update healthcheck + JWT env var for v4.38+ |
