# Deployment Runbook

Step-by-step guide to deploy the full Proxmox homelab infrastructure from scratch.

## Prerequisites

Install these on your local machine (Mac):

```bash
# Terraform
brew install terraform

# Ansible
brew install ansible

# talosctl
brew install siderolabs/tap/talosctl

# kubectl
brew install kubectl

# htpasswd (for Traefik dashboard password)
brew install httpd  # Provides htpasswd
```

## Phase 0: Proxmox Base Setup

### 0.1 Install Proxmox VE

1. Download Proxmox VE 8.x ISO from https://www.proxmox.com/en/downloads
2. Flash to USB with `dd` or Balena Etcher
3. Install on each node (2-3 nodes)
4. Set static IPs during install:
   - Node 1: `192.168.86.29`
   - Node 2: `192.168.86.30`
   - Node 3: `192.168.86.31` (optional)
5. Access web UI at `https://192.168.86.29:8006`

### 0.2 Create Proxmox Cluster

On node 1 (via web UI or SSH):
```bash
pvecm create homelab
```

On node 2 (and 3):
```bash
pvecm add 192.168.86.29
```

### 0.3 Repository Setup (Handled by Ansible)

The `make setup` playbook automatically switches from the enterprise repos (which require a paid subscription) to the free no-subscription community repos. You don't need to do this manually -- just be aware that `apt update` will fail until `make setup` runs if you haven't done this step.

If you want to do it manually before running Ansible:
```bash
# Remove enterprise repos
rm /etc/apt/sources.list.d/pve-enterprise.list
rm /etc/apt/sources.list.d/ceph.list

# Add community repos
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
echo "deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription" > /etc/apt/sources.list.d/ceph-no-subscription.list

apt update
```

### 0.4 Configure Ceph

Via the Proxmox web UI (Datacenter > Ceph):
1. Install Ceph on each node
2. Create OSDs from available disks on each node
3. Create a pool named `ceph-pool` (default size 3 for 3 nodes, or size 2 for 2 nodes)

Verify from SSH:
```bash
ceph status
ceph osd pool ls  # Should show "ceph-pool"
```

### 0.5 Create API Token

Via Proxmox web UI:
1. Datacenter > Permissions > API Tokens
2. User: `root@pam`
3. Token ID: `terraform`
4. Uncheck "Privilege Separation" (gives full permissions)
5. Save the token -- you'll need it for `terraform.tfvars`

Format: `root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 0.6 Run Base Setup Playbook

Update the inventory with your node IPs:
```bash
vim ansible/inventory/hosts.yml
```

Run the setup:
```bash
make setup
```

This verifies Proxmox version, Ceph health, network bridge, and downloads the Debian 12 LXC template.

---

## Phase 1: Cloudflare DNS + DDNS

### 1.1 Create Cloudflare Account

1. Sign up at https://dash.cloudflare.com/sign-up (free tier)
2. Click "Add a Site" and enter `woodhead.tech`
3. Select the **Free** plan

### 1.2 Transfer DNS from Squarespace

1. Cloudflare will show you 2 nameserver addresses (e.g., `ada.ns.cloudflare.com`)
2. Go to https://account.squarespace.com/domains/managed/woodhead.tech
3. Under DNS settings, change the nameservers to the Cloudflare ones
4. Wait for propagation (can take up to 24 hours, usually faster)

Verify:
```bash
dig woodhead.tech NS
# Should return Cloudflare nameservers
```

### 1.3 Create DNS Records in Cloudflare

In the Cloudflare dashboard for woodhead.tech:
1. Add A record: `woodhead.tech` -> your current public IP
2. Add A record: `*.woodhead.tech` -> your current public IP
3. Set both to **DNS only** (gray cloud) -- NOT proxied
4. TTL: 5 minutes (for DDNS updates)

### 1.4 Create Cloudflare API Token

1. My Profile > API Tokens > Create Token
2. Use the "Edit zone DNS" template
3. Zone Resources: Include > Specific Zone > `woodhead.tech`
4. Save the token

### 1.5 Note Zone ID and Record Info

1. On the woodhead.tech Overview page, the Zone ID is in the right sidebar
2. You'll need it for the DDNS env file

### 1.6 Configure DDNS

```bash
# Copy the example env file
cp scripts/ddns/cloudflare.env.example scripts/ddns/cloudflare.env

# Edit with your Cloudflare credentials
vim scripts/ddns/cloudflare.env
```

Fill in:
- `CF_API_TOKEN` - the API token from step 1.4
- `CF_ZONE_ID` - from step 1.5
- `CF_RECORD_NAMES` - `woodhead.tech,*.woodhead.tech`

### 1.7 Deploy DDNS

```bash
make ddns
```

This installs the script on the first Proxmox node and sets up a cron job every 5 minutes. Verify in syslog:
```bash
ssh root@192.168.86.29 "journalctl -t cloudflare-ddns --no-pager -n 20"
```

---

## Phase 2: Terraform Configuration

### 2.1 Configure terraform.tfvars

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars
```

Key values to update:
- `proxmox_endpoint` - your Proxmox URL (e.g., `https://192.168.86.29:8006`)
- `proxmox_api_token` - from Phase 0.4
- `proxmox_node` - node name (usually `pve` or `pve1`)
- `ssh_public_key` - your SSH public key (cat `~/.ssh/id_ed25519.pub`)
- Network IPs - adjust to match your subnet
- Domain settings

### 2.2 Download ISOs

Download service ISOs before creating VMs:
```bash
make prepare           # Talos ISO
make prepare-truenas   # TrueNAS Scale ISO
```

### 2.3 Initialize and Apply

```bash
# Download providers
make init

# Review what will be created
make plan

# Create everything (VMs + LXC containers)
make apply
```

This creates:
- 1 TrueNAS NAS VM (ID 300)
- 1 Home Assistant VM (ID 301)
- 1 control plane VM (ID 400)
- 2 worker VMs (IDs 410, 411)
- 1 Traefik LXC (ID 200)
- 1 Recipe site LXC (ID 201)
- 1 ARR stack LXC (ID 202)
- 1 Plex LXC (ID 203)
- 1 Jellyfin LXC (ID 204)
- 1 Monitoring LXC (ID 205)
- 1 OpenClaw LXC (ID 206)
- 1 Authelia LXC (ID 207)
- 1 WireGuard LXC (ID 208)

Or create infrastructure piecemeal:
```bash
make apply-truenas   # TrueNAS VM only
make apply-lxc       # LXC containers only
```

---

## Phase 3: Traefik Reverse Proxy

### 3.1 Generate Dashboard Password

```bash
htpasswd -nb admin your-secure-password-here
```

Copy the output and update `ansible/files/traefik/dynamic/dashboard.yml`:
- Replace `admin:$$apr1$$PLACEHOLDER$$REPLACE_WITH_HTPASSWD_HASH`
- Double all `$` signs (YAML escaping)

### 3.2 Deploy Traefik

```bash
make traefik
```

Pass the Cloudflare API token:
```bash
cd ansible && ansible-playbook playbooks/setup-traefik.yml \
  --extra-vars "cf_api_token=your-cloudflare-api-token"
```

### 3.3 Configure Port Forwarding

In the Google Home app (WiFi > Settings > Advanced Networking > Port Management):
- Forward port 80 -> `192.168.86.20:80`
- Forward port 443 -> `192.168.86.20:443`

### 3.4 Verify

```bash
# Should get Traefik 404 (no routes matched yet for this host)
curl -k https://192.168.86.20

# After recipe site is deployed, should work:
curl https://recipes.woodhead.tech
```

---

## Phase 4: Recipe Site

### 4.1 Deploy

```bash
make recipe-site
```

This copies and runs the install script from `~/WORKSPACE/recipes/site/deploy/install-recipe-site.sh` inside the LXC.

### 4.2 Verify

```bash
# Direct access (internal)
curl http://192.168.86.21:80

# Via Traefik (external)
curl https://recipes.woodhead.tech
```

### 4.3 Configure GitHub Webhook

In the recipes repo on GitHub (Settings > Webhooks > Add webhook):
1. Payload URL: `https://recipes.woodhead.tech/webhook`
2. Content type: `application/json`
3. Secret: SSH into the LXC and get it: `cat /opt/recipe-site/.webhook-secret`
4. Events: Just the push event

---

## Phase 5: TrueNAS Scale NAS

See [docs/TRUENAS-SETUP.md](TRUENAS-SETUP.md) for the full setup guide.

### 5.1 Download TrueNAS ISO

```bash
make prepare-truenas
```

### 5.2 Create the VM

```bash
make apply-truenas
```

### 5.3 Pass Through Data Disks

From the Proxmox host, attach physical disks for the ZFS pool:
```bash
# Identify disks by stable ID
ls -la /dev/disk/by-id/ | grep -v part

# Attach data disks (replace with your disk IDs)
qm set 300 -scsi1 /dev/disk/by-id/<disk-id-1>
qm set 300 -scsi2 /dev/disk/by-id/<disk-id-2>
```

### 5.4 Install TrueNAS

1. Open Proxmox web UI -> VM 300 (truenas) -> Console
2. Boot from ISO, install to the 16GB OS disk (NOT the data disks)
3. Set admin password, reboot

### 5.5 Configure TrueNAS

1. Set static IP: `192.168.86.40/24`, gateway `192.168.86.1`
2. Create ZFS pool from passthrough disks (mirror or RAIDZ1)
3. Create dataset: `pool/media`
4. Create NFS share: `/mnt/pool/media` -> authorized network `192.168.86.0/24`
5. Set permissions: `chown -R 1000:1000 /mnt/pool/media`

---

## Phase 6: ARR Media Stack

### 6.1 Deploy (Without NFS)

If TrueNAS isn't ready yet, the ARR stack uses local `/media` as a fallback:
```bash
make arr-stack
```

### 6.2 Deploy (With NFS from TrueNAS)

After TrueNAS is configured with NFS shares:
```bash
cd ansible && ansible-playbook playbooks/setup-arr-stack.yml \
  --extra-vars "nfs_server=192.168.86.40 nfs_share=/mnt/pool/media"
```

### 6.3 Configure Services

Access each service via its web UI:
| Service   | URL                        | First step                           |
|-----------|----------------------------|--------------------------------------|
| Prowlarr  | `http://192.168.86.22:9696`    | Add indexers                         |
| SABnzbd   | `http://192.168.86.22:8080`    | Configure Usenet server              |
| Sonarr    | `http://192.168.86.22:8989`    | Connect to Prowlarr + SABnzbd       |
| Radarr    | `http://192.168.86.22:7878`    | Connect to Prowlarr + SABnzbd       |
| Bazarr    | `http://192.168.86.22:6767`    | Connect to Sonarr + Radarr          |
| Overseerr | `http://192.168.86.22:5055`    | Connect to Sonarr + Radarr          |

### 6.4 Configure Gluetun VPN

Edit the Docker Compose file on the ARR LXC to add your VPN credentials:
```bash
ssh root@192.168.86.22
vim /opt/arr/docker-compose.yml
# Update gluetun environment: VPN_SERVICE_PROVIDER, WIREGUARD_PRIVATE_KEY, etc.
docker compose -f /opt/arr/docker-compose.yml up -d gluetun
```

### 6.5 Enable Traefik Routes (Optional)

To expose ARR services externally, uncomment the routes in
`ansible/files/traefik/dynamic/arr-stack.yml` and redeploy:
```bash
make traefik
```

---

## Phase 7: Plex and Jellyfin

Both media servers share the TrueNAS NFS media library. They use Intel
Quick Sync (iGPU) for hardware transcoding via `/dev/dri` passthrough.

### 7.1 Deploy Plex

```bash
make plex
```

With NFS media:
```bash
cd ansible && ansible-playbook playbooks/setup-plex.yml \
  --extra-vars "nfs_server=192.168.86.40 nfs_share=/mnt/pool/media"
```

Without GPU passthrough (software transcoding only):
```bash
cd ansible && ansible-playbook playbooks/setup-plex.yml \
  --extra-vars "gpu_passthrough=false"
```

Configure at `http://192.168.86.23:32400/web`:
1. Sign in with your Plex account
2. Add libraries: `/media/movies`, `/media/tv`, `/media/music`
3. Enable hardware transcoding (Settings > Transcoder, requires Plex Pass)

### 7.2 Deploy Jellyfin

```bash
make jellyfin
```

With NFS media:
```bash
cd ansible && ansible-playbook playbooks/setup-jellyfin.yml \
  --extra-vars "nfs_server=192.168.86.40 nfs_share=/mnt/pool/media"
```

Configure at `http://192.168.86.24:8096`:
1. Create admin account
2. Add libraries: `/media/movies`, `/media/tv`, `/media/music`
3. Enable VAAPI transcoding (Dashboard > Playback > Transcoding > `/dev/dri/renderD128`)

### 7.3 Enable Traefik Routes (Optional)

Uncomment routes in `ansible/files/traefik/dynamic/media-stack.yml` and:
```bash
make traefik
```

### 7.4 GPU Sharing Note

Both Plex and Jellyfin can share the same iGPU (`/dev/dri`). Intel Quick
Sync handles multiple transcoding sessions concurrently. Both LXCs must
run on the same Proxmox node that has the iGPU.

---

## Phase 8: Home Assistant

See [docs/HOMEASSISTANT-SETUP.md](HOMEASSISTANT-SETUP.md) for the full setup guide.

### 8.1 Create the VM

Unlike other VMs, HAOS uses a pre-built disk image instead of an ISO installer.
Terraform handles the image download and VM creation in one step:

```bash
make apply-homeassistant
```

This downloads the HAOS qcow2 image to Proxmox, decompresses it, and creates the
VM with the image imported as the boot disk. No separate ISO download needed.

### 8.2 First Boot

1. Open Proxmox web UI -> VM 301 (homeassistant) -> Console
2. HAOS boots automatically (no install wizard)
3. Wait 2-3 minutes for initial setup
4. The console shows the web UI URL

### 8.3 Configure

1. Access web UI at `http://192.168.86.41:8123`
2. Complete the onboarding wizard (create admin account, set location)
3. Set static IP: Settings -> System -> Network -> `192.168.86.41/24`

### 8.4 USB Passthrough (Optional)

For Zigbee/Z-Wave dongles:
```bash
# On Proxmox host, find your dongle's vendor:product ID
lsusb

# Pass it through to the VM
qm set 301 -usb0 host=<vendor>:<product>
```

Then in HA: Settings -> Devices & Services -> Add ZHA or Z-Wave JS integration.

### 8.5 Enable Traefik Route (Optional)

Uncomment the route in `ansible/files/traefik/dynamic/homeassistant.yml` and redeploy:
```bash
make traefik
```

---

## Phase 9: Kubernetes Cluster

### 9.1 Download Talos ISO

```bash
make prepare
```

### 9.2 Bootstrap

```bash
export CLUSTER_VIP="192.168.86.100"
export CONTROLPLANE_IPS="192.168.86.101"
export WORKER_IPS="192.168.86.111,192.168.86.112"
make bootstrap
```

### 9.3 Verify

```bash
export KUBECONFIG=talos/_out/kubeconfig
kubectl get nodes
# Should show 3 nodes in Ready state
```

### 9.4 Apply Base Manifests

```bash
# Without MetalLB
make k8s-base

# With MetalLB (for LoadBalancer services)
make k8s-base-metallb
```

### 9.5 Enable K8s Routing in Traefik

Once K8s has an ingress controller, uncomment the routes in `ansible/files/traefik/dynamic/k8s-ingress.yml` and redeploy:
```bash
make traefik
```

---

## Phase 10: Monitoring Stack

### 10.1 Create the LXC

```bash
make apply-lxc
```

This creates the monitoring LXC (VM ID 205, 192.168.86.25) along with any other LXCs.

### 10.2 Create Proxmox API Token for PVE Exporter

Via Proxmox web UI:
1. Datacenter > Permissions > Users > Add
   - User: `monitoring@pve`, Realm: `Proxmox VE authentication server`
2. Datacenter > Permissions > Roles > Add
   - Select `PVEAuditor` (read-only access)
3. Datacenter > Permissions > Add > User Permission
   - Path: `/`, User: `monitoring@pve`, Role: `PVEAuditor`
4. Datacenter > Permissions > API Tokens > Add
   - User: `monitoring@pve`, Token ID: `prometheus`
   - Uncheck "Privilege Separation"
5. Save the token value

### 10.3 Create Discord Webhook

1. Create a Discord server (or use existing)
2. Create a `#homelab-alerts` channel
3. Channel Settings > Integrations > Webhooks > New Webhook
4. Name it "Alertmanager" and select the `#homelab-alerts` channel
5. Copy the webhook URL (format: `https://discord.com/api/webhooks/<id>/<token>`)

### 10.4 Deploy Monitoring Stack

Basic deployment (configure credentials later):
```bash
make monitoring
```

With all credentials (recommended):
```bash
make monitoring \
  DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN" \
  GRAFANA_PASSWORD="your-secure-password" \
  PVE_USER=monitoring@pve \
  PVE_TOKEN_NAME=prometheus \
  PVE_TOKEN_VALUE="YOUR_TOKEN_VALUE"
```

### 10.5 Enable Traefik Metrics

Redeploy Traefik to add the Prometheus metrics entrypoint:
```bash
make traefik
```

This adds a `:8082` metrics endpoint that Prometheus scrapes for request data.

### 10.6 Grafana Dashboards

Four dashboards are auto-provisioned from JSON files in `ansible/files/monitoring/grafana/dashboards/`:

| Dashboard | Source ID | Purpose |
|-----------|-----------|---------|
| Proxmox VE | 10347 | Host/VM/LXC resource metrics (via PVE Exporter) |
| Docker Containers | 14282 | Container CPU, memory, network (via cAdvisor) |
| Traefik 3.x | 17346 | Request rate, latency, errors |
| Blackbox Exporter | 7587 | Service uptime, response time |

These load automatically on first boot -- no manual import needed. To add more,
download the JSON from grafana.com, replace `${DS_PROMETHEUS}` with `Prometheus`,
and place the file in the dashboards directory. Redeploy:
```bash
make monitoring
```

For the Kubernetes cluster overview dashboard (ID `315`), import manually after
bootstrapping K8s (it requires kube-state-metrics data to be useful).

### 10.7 Traefik Routes

Monitoring routes are pre-configured in `ansible/files/traefik/dynamic/monitoring.yml`:
- `grafana.woodhead.tech` -> :3000 (open)
- `prometheus.woodhead.tech` -> :9090 (behind Authelia 2FA)
- `alertmanager.woodhead.tech` -> :9093 (behind Authelia 2FA)

These are deployed automatically by `make traefik`. No uncommenting needed.

### 10.8 Deploy K8s Exporters (Optional)

After the K8s cluster is bootstrapped:
```bash
kubectl apply -f k8s/base/monitoring/kube-state-metrics.yml
kubectl apply -f k8s/base/monitoring/node-exporter-daemonset.yml
```

Then uncomment the K8s scrape configs in `ansible/files/monitoring/prometheus/prometheus.yml` and restart the stack:
```bash
ssh root@192.168.86.25 "cd /opt/monitoring && docker compose restart prometheus"
```

### 10.9 Verify

```bash
# Prometheus healthy
curl http://192.168.86.25:9090/-/healthy

# Grafana healthy
curl http://192.168.86.25:3000/api/health

# Check scrape targets (all jobs should be "up")
curl -s http://192.168.86.25:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Test Discord alerting (should appear in #homelab-alerts within 30s)
curl -X POST http://192.168.86.25:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"description":"Test alert from homelab"}}]'

# Traefik routes (after make traefik)
curl -I https://grafana.woodhead.tech
```

---

## Phase 11: Authelia SSO Gateway

### 11.1 Deploy

```bash
make authelia AUTHELIA_ADMIN_PASSWORD="your-strong-password"
```

This installs Docker, generates cryptographic secrets (JWT, session, storage encryption),
hashes the admin password with argon2id, and starts Authelia.

### 11.2 Configure

1. Access at `http://192.168.86.28:9091`
2. Log in with `admin` / the password you set
3. Register a TOTP device (Authy, Google Authenticator, etc.)

### 11.3 Protect Services

Authelia acts as a forwardAuth middleware for Traefik. Services with
`middlewares: [authelia@file]` in their Traefik dynamic config require
authentication before access. Prometheus and Alertmanager are protected by default.

### 11.4 Enable Traefik Route

The route at `ansible/files/traefik/dynamic/authelia.yml` (`auth.woodhead.tech`)
is already active. Redeploy Traefik if needed:
```bash
make traefik
```

---

## Phase 12: WireGuard VPN

See [docs/WIREGUARD-MANGO.md](WIREGUARD-MANGO.md) for connecting a GL-iNet Mango travel router.

### 12.1 Deploy

```bash
make wireguard
```

This installs WireGuard, enables IP forwarding, generates server + client keypairs
with preshared keys, templates `wg0.conf`, and starts the tunnel.

### 12.2 Configure Port Forwarding

In the Google Home app (WiFi > Settings > Advanced Networking > Port Management):
- Forward UDP port 51820 -> `192.168.86.39:51820`

### 12.3 Client Setup

Client configs are generated on the LXC at `/etc/wireguard/clients/` and fetched
to `ansible/files/wireguard/clients/` locally. Import the `.conf` file into the
WireGuard app on your phone/laptop.

### 12.4 Verify

```bash
# Check tunnel status on server
ssh root@192.168.86.39 "wg show"

# Test from client: ping the WireGuard server
ping 10.0.0.1
```

---

## Phase 13: Security Hardening

### 13.1 Verify SSH Key Access

Before running this, make sure you can SSH with keys:
```bash
ssh root@192.168.86.29  # Should work without password
```

### 13.2 Apply Hardening

```bash
make harden
```

This disables SSH password auth, installs fail2ban, and enables the Proxmox firewall.

---

## Day-2 Operations

### Adding a New LXC Service

1. Create a new Terraform file: `terraform/lxc-<service>.tf`
2. Add variables to `terraform/lxc-variables.tf`
3. Add a Traefik route: `ansible/files/traefik/dynamic/<service>.yml`
4. Create an Ansible playbook: `ansible/playbooks/setup-<service>.yml`
5. Add the host to `ansible/inventory/hosts.yml`
6. Run `make apply` then `make traefik`

### Updating Traefik Routes

Edit files in `ansible/files/traefik/dynamic/` and run:
```bash
make traefik
```
Traefik watches the dynamic config directory, so changes take effect within seconds.

### Checking DDNS Status

```bash
ssh root@192.168.86.29 "journalctl -t cloudflare-ddns --no-pager -n 20"
ssh root@192.168.86.29 "cat /var/lib/ddns/current-ip"
```

### Rebuilding K8s Cluster

The recipe site and Traefik LXC are independent of K8s:
```bash
make destroy   # Only destroys K8s VMs (LXCs are unaffected)
make apply     # Recreate VMs
make bootstrap # Re-bootstrap cluster
```

### Scaling K8s

Update `terraform.tfvars`:
```hcl
controlplane_count = 3
controlplane_ips   = ["192.168.86.101", "192.168.86.102", "192.168.86.103"]
```
Then: `make apply` and `make bootstrap`

---

## Troubleshooting

### Terraform can't connect to Proxmox
- Verify API token: `curl -k -H "Authorization: PVEAPIToken=root@pam!terraform=TOKEN" https://192.168.86.29:8006/api2/json/version`
- Check `proxmox_insecure = true` in tfvars if using self-signed certs

### DDNS not updating
- Check cron: `ssh root@192.168.86.29 "crontab -l"`
- Check logs: `ssh root@192.168.86.29 "journalctl -t cloudflare-ddns"`
- Test manually: `ssh root@192.168.86.29 "/usr/local/bin/cloudflare-ddns -v"`

### Traefik not getting certificates
- Check Cloudflare API token permissions (Zone:DNS:Edit)
- Check Traefik logs: `ssh root@192.168.86.20 "journalctl -u traefik --no-pager -n 50"`
- Verify DNS propagation: `dig recipes.woodhead.tech`

### Talos nodes stuck in maintenance
- Check talosctl: `TALOSCONFIG=talos/_out/talosconfig talosctl dmesg --nodes 192.168.86.101`
- Verify Proxmox console: check the VM serial console in Proxmox web UI

### Recipe site not reachable
- Check service: `ssh root@192.168.86.21 "systemctl status recipe-site"`
- Check nginx: `ssh root@192.168.86.21 "systemctl status nginx"`
- Check Traefik route: `curl -I https://recipes.woodhead.tech`
