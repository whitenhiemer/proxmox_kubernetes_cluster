---
sidebar_position: 10
title: Email Server
---

# Email Server (Mailcow)

LXC 212 | `192.168.86.34` | [mail.woodhead.tech](https://mail.woodhead.tech)

Self-hosted Mailcow email stack for the `woodhead.tech` domain. Provides mailboxes for personal use and service accounts (ClawBot, Alertmanager).

## Architecture

- Mailcow Dockerized: Postfix, Dovecot, Rspamd, SOGo webmail, MariaDB, Redis (18 containers)
- Runs on an unprivileged Debian LXC with Docker and nesting enabled
- ClamAV disabled via `docker-compose.override.yml` to save ~1GB RAM
- Outbound mail relayed through Mailgun (ISP blocks port 25 outbound)
- Inbound mail received directly (ports 25/465/587/993 forwarded via Google Nest WiFi)
- TLS terminated at Traefik; Mailcow HTTP on port 8080 behind `mail.woodhead.tech`

## Port Forwards (Google Nest WiFi)

| Port | Protocol | Service |
|------|----------|---------|
| 25   | TCP      | SMTP inbound |
| 465  | TCP      | SMTPS |
| 587  | TCP      | Submission |
| 993  | TCP      | IMAPS |

All forward to `192.168.86.34`. Configure via Google Home app > Wi-Fi > Network settings > Advanced networking > Port management.

## DNS Records (Cloudflare)

| Type | Name | Content |
|------|------|---------|
| MX   | `woodhead.tech` | `mail.woodhead.tech` (priority 10) |
| A    | `mail` | `<public IP>` (proxied or DNS-only) |
| TXT  | `woodhead.tech` | `v=spf1 mx a:mail.woodhead.tech ~all` |
| TXT  | `_dmarc.woodhead.tech` | `v=DMARC1; p=quarantine; rua=mailto:postmaster@woodhead.tech` |
| TXT  | `dkim._domainkey.woodhead.tech` | DKIM public key (from Mailcow admin) |

## Mailboxes

| Address | Purpose |
|---------|---------|
| `brandon@woodhead.tech` | Personal email |
| `clawbot@woodhead.tech` | ClawBot service account |
| `clawbot-0@woodhead.tech` | ClawBot git identity (GitHub account email) |
| `alerts@woodhead.tech` | Alertmanager notifications |

## Deploy

```bash
# Provision the LXC
make plan-lxc
make apply-lxc

# Deploy Mailcow
make mailserver   # runs ansible/playbooks/setup-mailserver.yml
```

After deployment, the Ansible playbook:
1. Installs Docker and prerequisites (including `jq`)
2. Disables system Postfix (conflicts on port 25)
3. Clones Mailcow and runs `generate_config.sh`
4. Configures Mailgun SMTP relay
5. Disables ClamAV via override
6. Remaps HTTP to 8080, HTTPS to 8443
7. Pulls images and starts the stack

## Outbound Relay (Mailgun)

ISP blocks outbound port 25/587, so Mailcow uses Mailgun as a smarthost relay.

- Sandbox domain: `sandbox754260d8aff24e45b8c829ec0cd64915.mailgun.org`
- Configured as relayhost in Mailcow admin API
- To send to arbitrary recipients, verify the `woodhead.tech` domain in Mailgun

## LXC Configuration

The unprivileged LXC requires rlimit overrides for Docker workloads. These are set on the Proxmox host in `/etc/pve/lxc/212.conf`:

```
lxc.prlimit.nofile: 1048576
lxc.prlimit.nproc: unlimited
lxc.cap.drop:
```

## Verify

```bash
# Check Mailcow web UI
curl -I https://mail.woodhead.tech

# Check containers (from LXC)
ssh root@192.168.86.34 "cd /opt/mailcow-dockerized && docker compose ps"

# Test SMTP inbound (from another host on LAN)
echo "test" | mail -s "test" brandon@woodhead.tech

# Check mail logs
ssh root@192.168.86.34 "cd /opt/mailcow-dockerized && docker compose logs postfix-mailcow --tail=20"
```

## Troubleshooting

- **rlimits error on container start**: Add the `lxc.prlimit.*` entries to the LXC config on the Proxmox host and restart the LXC.
- **Port 25 already in use**: System Postfix is running. Disable it: `systemctl disable --now postfix`.
- **Traefik returns 400**: Ensure the route points to HTTP port 8080, not HTTPS 8443 (TLS is terminated at Traefik).
- **Outbound mail not delivered**: Check Mailgun relay config and verify the sandbox domain allows the recipient. Verify `woodhead.tech` in Mailgun for unrestricted sending.
- **DKIM failures**: Regenerate DKIM key in Mailcow admin, update the `dkim._domainkey` TXT record in Cloudflare.
