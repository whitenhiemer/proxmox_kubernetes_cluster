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
   - Node 1: `10.0.0.10`
   - Node 2: `10.0.0.11`
   - Node 3: `10.0.0.12` (optional)
5. Access web UI at `https://10.0.0.10:8006`

### 0.2 Create Proxmox Cluster

On node 1 (via web UI or SSH):
```bash
pvecm create homelab
```

On node 2 (and 3):
```bash
pvecm add 10.0.0.10
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

### 0.3 Configure Ceph

Via the Proxmox web UI (Datacenter > Ceph):
1. Install Ceph on each node
2. Create OSDs from available disks on each node
3. Create a pool named `ceph-pool` (default size 3 for 3 nodes, or size 2 for 2 nodes)

Verify from SSH:
```bash
ceph status
ceph osd pool ls  # Should show "ceph-pool"
```

### 0.4 Create API Token

Via Proxmox web UI:
1. Datacenter > Permissions > API Tokens
2. User: `root@pam`
3. Token ID: `terraform`
4. Uncheck "Privilege Separation" (gives full permissions)
5. Save the token -- you'll need it for `terraform.tfvars`

Format: `root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 0.5 Run Base Setup Playbook

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
ssh root@10.0.0.10 "journalctl -t cloudflare-ddns --no-pager -n 20"
```

---

## Phase 2: Terraform Configuration

### 2.1 Configure terraform.tfvars

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars
```

Key values to update:
- `proxmox_endpoint` - your Proxmox URL (e.g., `https://10.0.0.10:8006`)
- `proxmox_api_token` - from Phase 0.4
- `proxmox_node` - node name (usually `pve` or `pve1`)
- `ssh_public_key` - your SSH public key (cat `~/.ssh/id_ed25519.pub`)
- Network IPs - adjust to match your subnet
- Domain settings

### 2.2 Initialize and Apply

```bash
# Download providers
make init

# Review what will be created
make plan

# Create everything (VMs + LXC containers)
make apply
```

This creates:
- 1 control plane VM (ID 400)
- 2 worker VMs (IDs 410, 411)
- 1 Traefik LXC (ID 200)
- 1 Recipe site LXC (ID 201)

If you only want LXC containers first:
```bash
make apply-lxc
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

### 3.3 Configure Router Port Forwarding

On your home router, forward:
- External port 80 -> `10.0.0.20:80`
- External port 443 -> `10.0.0.20:443`

### 3.4 Verify

```bash
# Should get Traefik 404 (no routes matched yet for this host)
curl -k https://10.0.0.20

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
curl http://10.0.0.21:80

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

## Phase 5: Kubernetes Cluster

### 5.1 Download Talos ISO

```bash
make prepare
```

### 5.2 Bootstrap

```bash
export CLUSTER_VIP="10.0.0.100"
export CONTROLPLANE_IPS="10.0.0.101"
export WORKER_IPS="10.0.0.111,10.0.0.112"
make bootstrap
```

### 5.3 Verify

```bash
export KUBECONFIG=talos/_out/kubeconfig
kubectl get nodes
# Should show 3 nodes in Ready state
```

### 5.4 Apply Base Manifests

```bash
# Without MetalLB
make k8s-base

# With MetalLB (for LoadBalancer services)
make k8s-base-metallb
```

### 5.5 Enable K8s Routing in Traefik

Once K8s has an ingress controller, uncomment the routes in `ansible/files/traefik/dynamic/k8s-ingress.yml` and redeploy:
```bash
make traefik
```

---

## Phase 6: Security Hardening

### 6.1 Verify SSH Key Access

Before running this, make sure you can SSH with keys:
```bash
ssh root@10.0.0.10  # Should work without password
```

### 6.2 Apply Hardening

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
ssh root@10.0.0.10 "journalctl -t cloudflare-ddns --no-pager -n 20"
ssh root@10.0.0.10 "cat /var/lib/ddns/current-ip"
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
controlplane_ips   = ["10.0.0.101", "10.0.0.102", "10.0.0.103"]
```
Then: `make apply` and `make bootstrap`

---

## Troubleshooting

### Terraform can't connect to Proxmox
- Verify API token: `curl -k -H "Authorization: PVEAPIToken=root@pam!terraform=TOKEN" https://10.0.0.10:8006/api2/json/version`
- Check `proxmox_insecure = true` in tfvars if using self-signed certs

### DDNS not updating
- Check cron: `ssh root@10.0.0.10 "crontab -l"`
- Check logs: `ssh root@10.0.0.10 "journalctl -t cloudflare-ddns"`
- Test manually: `ssh root@10.0.0.10 "/usr/local/bin/cloudflare-ddns -v"`

### Traefik not getting certificates
- Check Cloudflare API token permissions (Zone:DNS:Edit)
- Check Traefik logs: `ssh root@10.0.0.20 "journalctl -u traefik --no-pager -n 50"`
- Verify DNS propagation: `dig recipes.woodhead.tech`

### Talos nodes stuck in maintenance
- Check talosctl: `TALOSCONFIG=talos/_out/talosconfig talosctl dmesg --nodes 10.0.0.101`
- Verify Proxmox console: check the VM serial console in Proxmox web UI

### Recipe site not reachable
- Check service: `ssh root@10.0.0.21 "systemctl status recipe-site"`
- Check nginx: `ssh root@10.0.0.21 "systemctl status nginx"`
- Check Traefik route: `curl -I https://recipes.woodhead.tech`
