---
sidebar_position: 8
title: Client Support
---

# Client Support Runbook

Human-executable. No AI required. Covers diagnosing and resolving issues on a
live ShopStack client deployment.

**Access requirements:**
- WireGuard route active: `sudo ip route add 10.99.0.0/24 via 192.168.86.39`
- SSH key: `~/.ssh/id_ansible`
- Client spoke IPs: see [ShopStack Deployment](./shopstack-deployment) → Spoke IP Allocation Log
- Customer inventory: `~/Workspace/shopstack/ansible/inventory/customers/<client>.yml`

**Support commitment:** Same-day response on weekdays. Best-effort on weekends.

---

## Step 1 — Triage: What's Actually Down?

Before SSHing anywhere, ask the client exactly what they're seeing.

**Questions to ask:**
- Which service is affected? (email, files, invoicing, or all of them?)
- What error message or behavior are they seeing?
- When did it start?
- Did anything change recently? (new device, new staff member, password change)

**Most issues fall into one of four categories:**

| Symptom | Likely cause |
|---------|-------------|
| One service is down, others work | That service's Docker container crashed |
| All services unreachable (HTTPS) | Traefik is down, or the box lost internet |
| Email not sending/receiving | Mailcow issue or DNS/MX misconfiguration |
| Client can't log in | Wrong password, or Authentik is down |
| Box completely unreachable | Box offline, WireGuard spoke dropped, or power/network issue |

---

## Step 2 — Check Uptime Kuma First

Before SSHing, check Uptime Kuma — it tells you what's up and what's down
without touching the box.

URL: `https://status.CLIENT_SLUG.woodhead.tech`

Or SSH to the box and check the Docker stack status (Step 3).

---

## Step 3 — SSH to the Client Box

```bash
# Ensure WireGuard route is active first
sudo ip route add 10.99.0.0/24 via 192.168.86.39 2>/dev/null || true

# SSH to the client (Debian 12 uses 'admin', not root)
ssh -i ~/.ssh/id_ansible admin@10.99.0.X   # replace X with client's spoke IP
```

Spoke IPs are in the [ShopStack Deployment](./shopstack-deployment) → Spoke IP Allocation Log.

If the box is unreachable via WireGuard, try the public IP (EC2 Elastic IP or
on-prem public IP) as a fallback:
```bash
ssh -i ~/.ssh/id_ansible admin@PUBLIC_IP
```

If still unreachable: the box may be offline. See "Box completely offline" section below.

---

## Step 4 — Check All Services

Once SSH'd in, run a quick health check:

```bash
# Check all running Docker containers across the box
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Any container not showing `Up X hours` is a problem. Note which ones.

**Service → directory mapping:**

| Service | Directory | Key containers |
|---------|-----------|---------------|
| Traefik | `/opt/traefik` | traefik |
| Authentik | `/opt/authentik` | authentik-server, authentik-worker, authentik-db, authentik-redis |
| Mailcow | `/opt/mailcow-dockerized` | mailcowdockerized-postfix-1, mailcowdockerized-dovecot-1, mailcowdockerized-nginx-1 |
| Nextcloud | `/opt/nextcloud` | nextcloud-app, nextcloud-db |
| Invoice Ninja | `/opt/invoiceninja` | invoiceninja-app, invoiceninja-db |
| Uptime Kuma | `/opt/uptime-kuma` | uptime-kuma |
| WooCommerce | `/opt/woocommerce` | woocommerce-app, woocommerce-db |

---

## Step 5 — Resolve by Symptom

### One container is down

```bash
cd /opt/SERVICE_NAME
docker compose logs --tail=50    # read the error
docker compose restart           # try a restart first
docker ps                        # confirm it came back up
```

If it restarted successfully, check the service URL to confirm it's serving traffic.

**If it keeps crashing:** read the logs carefully — look for `Error`, `FATAL`,
`permission denied`, or `out of memory`. Common fixes below.

---

### All HTTPS services unreachable (Traefik down)

```bash
cd /opt/traefik
docker compose logs --tail=50
docker compose restart
```

If Traefik fails to start, check the dynamic config for syntax errors:
```bash
ls /etc/traefik/dynamic/
cat /etc/traefik/dynamic/nextcloud.yml   # or whichever was last edited
```

A bad YAML file in `/etc/traefik/dynamic/` will prevent Traefik from loading.
Fix the YAML or remove the bad file, then restart.

---

### Email not working

**Client can't send outbound mail:**
```bash
cd /opt/mailcow-dockerized
docker compose logs --tail=50 postfix-mailcow
```

Look for relay errors, authentication failures, or DNS issues.
Common cause: Mailgun relay credentials expired or the SMTP password changed.

**Client not receiving inbound mail:**
Check MX records are still correct:
```bash
dig MX client-domain.com
```
Should point to `mail.CLIENT_SLUG.woodhead.tech`. If it doesn't, DNS was changed
outside of your control — client's registrar settings need to be updated.

**Email marked as spam:**
Check SPF/DKIM/DMARC:
```bash
dig TXT client-domain.com          # look for SPF record
dig TXT _dmarc.client-domain.com   # DMARC
```
If records are missing, they were likely deleted. Re-add them in Cloudflare DNS
per the Mailcow setup (Mailcow admin → Configuration → DNS shows the required records).

---

### Client can't log in

**Wrong password (most common):**
Reset it for them in the relevant service's admin panel:
- Mailcow: `https://mail.CLIENT_SLUG.woodhead.tech` → admin login → Edit mailbox
- Nextcloud: admin login → Users → reset password
- Invoice Ninja: SSH to box → `docker exec -it invoiceninja-app php artisan ninja:reset-password --email=...`
- Authentik: `https://auth.CLIENT_SLUG.woodhead.tech` → admin → Users → Set password

**Authentik is down (nobody can log in to anything):**
```bash
cd /opt/authentik
docker compose logs --tail=50
docker compose restart
```
Authentik protects Traefik, Nextcloud, and Uptime Kuma. If it's down, those
interfaces show a login error. Invoice Ninja and Mailcow have their own auth and
are unaffected.

---

### Invoice Ninja blank page or errors

Storage directory ownership issue (most common cause):
```bash
cd /opt/invoiceninja
docker exec invoiceninja-app ls -la /var/www/app/storage
# if not owned by 1500:1500:
chown -R 1500:1500 /opt/invoiceninja/storage /opt/invoiceninja/public
docker compose restart invoiceninja
```

---

### WooCommerce (ShopStack Online clients only)

**WordPress shows error or white screen:**
```bash
cd /opt/woocommerce
docker compose logs --tail=50 woocommerce-app
docker compose restart
```

If DB connection error:
```bash
docker compose restart woocommerce-db
sleep 10
docker compose restart woocommerce-app
```

---

### Box completely offline (worst case)

**For AWS (Cloud) clients:**

1. Log in to AWS Console → EC2 → find the client's instance by `client_name` tag
2. Check instance state — if "stopped", start it: Actions → Start instance
3. If running but unreachable, try a reboot: Actions → Reboot instance
4. If the instance is terminated (rare, billing issue): provision a new one via Terraform and restore from latest snapshot (if backups configured)

Check the Elastic IP is still associated — if the instance was stopped and started
without a reserved EIP, the IP may have changed. Re-associate or update DNS.

**For On-Premises (Plug & Play) clients:**

The box is physically at the client's location. You cannot access it remotely if
it's offline.

Steps:
1. Ask the client to check the box — is the power light on?
2. If powered off: ask them to press the power button
3. If powered on but no network light: ask them to unplug and replug the ethernet cable
4. If it boots but you still can't reach it: ask them to check their router — the box's IP may have changed if DHCP reservation was lost

Once the box is back on the network, SSH in and run Step 4 to check container status.

---

## Step 6 — Communicate With the Client

**During the incident:**
- Send a text or email when you start working on it: "On it — investigating now."
- Update them every 30 minutes if it's taking time: "Still working on it — found the issue, applying the fix."

**When resolved:**
- Tell them what happened in plain language (no Ansible/Docker jargon):
  > "The invoicing service restarted unexpectedly — we've brought it back up and it's running normally. No data was lost."
- Tell them if any action is needed on their end (e.g., log back in, re-send a draft invoice)
- If the same issue happens twice: tell them what you're doing to prevent it from recurring

**Template — issue resolved:**
> Hi [name],
>
> [Service] is back up. Root cause: [plain English explanation]. Everything looks
> normal now — let me know if you run into anything else.
>
> Brandon

---

## Step 7 — Post-Incident

After every support incident, do two things:

**1. Note it in the customer inventory file:**
```yaml
# Add to ~/Workspace/shopstack/ansible/inventory/customers/CLIENT.yml
incidents:
  - date: 2026-05-16
    service: invoiceninja
    cause: storage permissions
    resolution: chowned to 1500, restarted container
    time_to_resolve: 25 min
```

**2. Ask yourself: can this be prevented?**
- If a container keeps crashing: add a health check or restart policy to docker-compose.yml and redeploy
- If a client keeps forgetting their password: set up password manager recommendation on next call
- If DNS was changed by the client: add DNS management to the contract scope or advise them to keep Cloudflare credentials safe

---

## Emergency Contacts & Credentials Reference

| Item | Location |
|------|----------|
| Spoke IP allocations | [ShopStack Deployment](./shopstack-deployment) |
| Customer inventory files | `~/Workspace/shopstack/ansible/inventory/customers/` |
| Cloudflare API token | `~/Workspace/proxmox_kubernetes_cluster/scripts/ddns/cloudflare.env` |
| AWS CLI credentials | `~/.aws/credentials` |
| SSH key | `~/.ssh/id_ansible` |
| WireGuard hub | `ssh -i ~/.ssh/id_ansible root@192.168.86.39` |
