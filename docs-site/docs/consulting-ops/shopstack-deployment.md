---
sidebar_position: 2
title: ShopStack Deployment
---

# ShopStack Deployment Runbook

Human-executable. No AI required. Cover both deployment paths end to end.

**Repos:**
- IaC: `~/Workspace/shopstack/`
- Ansible: `~/Workspace/shopstack/ansible/`
- Terraform: `~/Workspace/shopstack/terraform/aws/`

**Support email:** brandon@woodhead.tech
**Cal.com:** cal.com/brandon-woodward-3nlfbd

---

## Before You Start

Have the following ready before touching the keyboard:

| Item | Where to get it |
|------|----------------|
| Client short slug (e.g. `oak-vetclinic`) | Intake form |
| Client domain (e.g. `oak.woodhead.tech`) | Intake form or assign from woodhead.tech subdomain |
| Client admin email | Intake form |
| Your current public IP | `curl ifconfig.me` |
| Cloudflare API token | `~/Workspace/proxmox_kubernetes_cluster/scripts/ddns/cloudflare.env` |
| AWS CLI configured | `aws sts get-caller-identity` — must return your account |
| SSH key imported to AWS | Run once: `aws ec2 import-key-pair --key-name shopstack-key --public-key-material fileb://~/.ssh/id_ansible.pub` |

---

## Path A: AWS Cloud Deployment

Use this for all new ShopStack Online clients and any client who chose the Cloud tier.

### Step 1 — Terraform: Provision the EC2 instance

```bash
cd ~/Workspace/shopstack/terraform/aws

# Copy and edit the vars file
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region        = "us-east-1"
client_name       = "CLIENT_SLUG"        # e.g. oak-vetclinic
instance_type     = "t3.large"
disk_size_gb      = 40
key_pair_name     = "shopstack-key"
subnet_id         = "subnet-xxxxxxxxx"   # see note below
admin_cidr_blocks = ["YOUR.IP.HERE/32"]  # curl ifconfig.me
```

**Finding subnet_id:** AWS Console → VPC → Subnets → pick any public subnet in us-east-1.
Default VPC subnet IDs start with `subnet-`. Use one tagged `Public` or with `Auto-assign public IPv4` enabled.

```bash
terraform init    # first time only per machine
terraform apply
```

Takes ~30 seconds. Note the outputs:
- `public_ip` — the Elastic IP (static, set this in DNS)
- `instance_id` — save for the customer inventory file

### Step 2 — DNS: Create Cloudflare records

Log in to Cloudflare → woodhead.tech → DNS.

Create two records (DNS-only, **not proxied**):

| Type | Name | Value | Proxied |
|------|------|-------|---------|
| A | `CLIENT_SLUG` | `ELASTIC_IP` | No |
| A | `*.CLIENT_SLUG` | `ELASTIC_IP` | No |

Example: `oak-vetclinic.woodhead.tech` and `*.oak-vetclinic.woodhead.tech` → `54.x.x.x`

Wait 1–2 minutes for DNS to propagate before running Ansible.

Verify: `dig +short oak-vetclinic.woodhead.tech` — should return the Elastic IP.

### Step 3 — Update inventory.ini

```bash
cd ~/Workspace/shopstack/ansible
```

Edit `inventory.ini` to point at the new EC2:

```ini
[shopstack]
shopstack ansible_host=ELASTIC_IP ansible_user=admin ansible_ssh_private_key_file=~/.ssh/id_ansible
```

Test SSH before running Ansible (Debian 12 takes ~30s after Terraform to accept connections):

```bash
ssh -i ~/.ssh/id_ansible -o StrictHostKeyChecking=accept-new admin@ELASTIC_IP 'echo ok'
```

If it times out, wait 30 seconds and try again.

### Step 4 — Create deploy-vars.yml

```bash
cd ~/Workspace/shopstack/ansible
```

Create `deploy-vars.yml` (never commit this file — it contains secrets):

```yaml
# Core
domain: CLIENT_SLUG.woodhead.tech
cf_api_token: CLOUDFLARE_TOKEN          # from ~/Workspace/proxmox_kubernetes_cluster/scripts/ddns/cloudflare.env
acme_email: brandon@woodhead.tech
customer_name: CLIENT_SLUG
wg_spoke_ip: 10.99.0.X                  # next available IP — see WireGuard section below

# Databases
postgres_password: GENERATE             # openssl rand -hex 16
nextcloud_db_pass: GENERATE
nextcloud_admin_pass: GENERATE
invoiceninja_db_pass: GENERATE
invoiceninja_app_key: "base64:GENERATE" # openssl rand -base64 32

# Mail
mailcow_domain: CLIENT_SLUG.woodhead.tech
mailcow_hostname: mail.CLIENT_SLUG.woodhead.tech

# ShopStack Online only — omit for brick-and-mortar clients
# enable_woocommerce: true
# woocommerce_db_pass: GENERATE
# wp_admin_pass: GENERATE
# wp_site_title: "Client Store Name"
```

**Generate passwords (run each separately, copy output):**
```bash
openssl rand -hex 16          # for postgres_password, nextcloud_db_pass, etc.
openssl rand -base64 32       # for invoiceninja_app_key (prefix with "base64:")
openssl rand -hex 16          # for nextcloud_admin_pass, wp_admin_pass
```

Save the passwords somewhere safe — you'll need them for client handoff.

### Step 5 — WireGuard spoke: assign an IP

The management WireGuard hub runs on LXC 192.168.86.39.

**Current spoke IP allocations:**
- 10.99.0.1 — hub (wg1 LXC)
- 10.99.0.2 — tshirts-demo

Assign the next available IP to this client (10.99.0.3, 10.99.0.4, etc.).
Set `wg_spoke_ip` in deploy-vars.yml to that IP.

The Ansible spoke playbook handles the rest during step 6.

After deploy completes, add a route on your machine so you can reach the client via WireGuard:
```bash
sudo ip route add 10.99.0.0/24 via 192.168.86.39
```

Update this runbook with the new spoke IP allocation when done.

### Step 6 — Run Ansible

```bash
cd ~/Workspace/shopstack/ansible
ansible-playbook shopstack.yml -i inventory.ini --become \
  --extra-vars "@../profiles/aws.yml" \
  --extra-vars "@deploy-vars.yml"
```

This runs all 9 steps (10 if WooCommerce enabled). Takes 15–25 minutes.

If a step fails, fix the issue and re-run — Ansible is idempotent. Common failures:
- **Mailcow step hangs**: Mailcow takes 5–10 min to pull images. Wait it out.
- **TLS cert timeout**: DNS didn't propagate. Wait 5 min, re-run.
- **SSH connection refused**: EC2 not ready. Wait 30s, re-run.

### Step 7 — Verify all services

After Ansible completes, hit each URL and confirm it loads:

| Service | URL | Expected |
|---------|-----|----------|
| Traefik dashboard | `https://traefik.CLIENT_SLUG.woodhead.tech` | Login prompt |
| Authentik SSO | `https://auth.CLIENT_SLUG.woodhead.tech` | Authentik welcome |
| Mailcow | `https://mail.CLIENT_SLUG.woodhead.tech` | Mailcow login |
| Nextcloud | `https://files.CLIENT_SLUG.woodhead.tech` | Nextcloud login |
| Invoice Ninja | `https://billing.CLIENT_SLUG.woodhead.tech` | Setup wizard |
| Uptime Kuma | `https://status.CLIENT_SLUG.woodhead.tech` | Dashboard |
| WooCommerce (Online only) | `https://shop.CLIENT_SLUG.woodhead.tech` | WordPress storefront |

TLS should be valid (Let's Encrypt via Cloudflare DNS-01). If you get a cert error, wait 2 minutes and reload — cert provisioning runs after Traefik starts.

SSH verification via WireGuard (after route is added):
```bash
ssh -i ~/.ssh/id_ansible admin@10.99.0.X 'uptime'
```

### Step 8 — Create customer inventory file

```bash
cd ~/Workspace/shopstack/ansible/inventory/customers/
```

Create `CLIENT_SLUG.yml`:

```yaml
all:
  hosts:
    CLIENT_SLUG:
      ansible_host: 10.99.0.X
      ansible_user: admin
      ansible_ssh_private_key_file: ~/.ssh/id_ansible
      ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new'

      customer_name: CLIENT_SLUG
      domain: CLIENT_SLUG.woodhead.tech
      wg_ip: 10.99.0.X
      tier: cloud   # or: online, on-prem, plug-and-play

      services:
        - mailcow
        - nextcloud
        - invoiceninja
        - uptime-kuma
        # - woocommerce   # ShopStack Online only

      ec2_instance_id: i-XXXXXXXXXXXXXXXXX
      ec2_public_ip: ELASTIC_IP
```

Commit the inventory file:
```bash
cd ~/Workspace/shopstack
git add ansible/inventory/customers/CLIENT_SLUG.yml
git commit -m "ops: add CLIENT_SLUG customer inventory"
git push origin main
```

Do NOT commit `ansible/deploy-vars.yml`, `terraform/aws/tfplan`, or `ansible/spoke/peers/`.

### Step 9 — Initial client setup (post-deploy)

Complete before handing off to client:

**Mailcow:** Log in as admin → create the client's email domain, create their primary mailbox.

**Invoice Ninja:** First-run wizard — create the admin account using the client's email. Set company name, logo, and currency.

**Nextcloud:** Log in as admin (password from `nextcloud_admin_pass`) → create a user account for the client.

**Authentik:** Review default application access — the client should use Authentik SSO to log in to Traefik, Nextcloud, and Uptime Kuma.

### Step 10 — Handoff

Send the kickoff email (`~/WOODHEAD_CONSULTING/proposals/sample-vetclinic-kickoff-email.md`).

Collect from client:
- Staff email addresses (for Mailcow mailboxes)
- Business logo (for Invoice Ninja)
- Preferred billing day of month (for Invoice Ninja recurring invoices)

For Plug & Play clients: include the setup card (`onboarding/shopstack-setup-card.html`) printed inside the box.

---

## Path B: On-Premises (Plug & Play)

### Pre-steps (before running Ansible)

1. Flash Debian 12 to USB → install on the Beelink EQ12
2. During install: set hostname to `CLIENT_SLUG`, create user `admin`
3. After boot: enable SSH
   ```bash
   systemctl enable --now ssh
   ```
4. Copy your SSH public key to the box:
   ```bash
   ssh-copy-id -i ~/.ssh/id_ansible.pub admin@BEELINK_LAN_IP
   ```
5. In the client's router: set a DHCP reservation for the Beelink's MAC address
6. In the client's router: port-forward the following to the Beelink's LAN IP:
   | Port | Protocol | Purpose |
   |------|----------|---------|
   | 80 | TCP | HTTP (redirect to HTTPS) |
   | 443 | TCP | HTTPS (all web services) |
   | 25, 465, 587 | TCP | Email (SMTP) |
   | 993, 995 | TCP | Email (IMAP/POP3) |
   | 51820 | UDP | WireGuard (remote management) |
7. In Cloudflare DNS: create A records pointing to the client's public IP (get it at ifconfig.me on their network). Use DDNS — see on-prem profile: `ddns_enabled: true` handles this automatically after Ansible runs.

### Ansible

Same as Path A steps 3–9, but use the on-prem profile and the Beelink's LAN IP:

```bash
# inventory.ini:
shopstack ansible_host=BEELINK_LAN_IP ansible_user=admin ansible_ssh_private_key_file=~/.ssh/id_ansible

# Run:
ansible-playbook shopstack.yml -i inventory.ini --become \
  --extra-vars "@../profiles/on-prem.yml" \
  --extra-vars "@deploy-vars.yml"
```

After Ansible completes, the Beelink is ready to ship or drop off.

---

## Spoke IP Allocation Log

Update this table every time a new client is deployed.

| IP | Client | Domain | Deployed |
|----|--------|--------|---------|
| 10.99.0.1 | hub | — | — |
| 10.99.0.2 | tshirts-demo | tshirts-demo.woodhead.tech | 2026-05-16 |
| 10.99.0.3 | — | — | — |

---

## Common Issues

**"TASK [mailcow] failed: timeout"**
Mailcow pulls ~3 GB of Docker images. Re-run Ansible — it's idempotent and will skip completed steps.

**"TLS handshake error / cert not valid"**
DNS propagation is slow. Wait 2–5 minutes and reload. If still failing, SSH to the box and check: `docker logs traefik 2>&1 | grep -i acme`

**"ansible_host unreachable"**
For AWS: EC2 is still booting. Wait 30–60s. For on-prem: verify port-forward and that SSH is running (`systemctl status ssh`).

**"WireGuard spoke not connecting"**
On the hub: `wg show wg1` — check if the peer handshake is recent. If 0 bytes received, the spoke config may have the wrong hub public key or endpoint. SSH to the spoke via public IP and check `wg show`.

**"Invoice Ninja blank page"**
Storage directories aren't chowned to UID 1500. SSH to box: `chown -R 1500:1500 /opt/invoiceninja/storage /opt/invoiceninja/public`. Then `docker compose restart invoiceninja` in `/opt/invoiceninja/`.

**"I need to re-run just one service"**
Ansible is idempotent — re-running the full playbook is safe. Or SSH to the box and restart the specific Docker Compose stack: `cd /opt/SERVICE && docker compose restart`
