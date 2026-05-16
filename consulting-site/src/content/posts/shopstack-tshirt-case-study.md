---
title: "From PayPal.me links to a real business stack — a T-shirt seller case study"
description: "A friend who sells custom T-shirts was running her business on Gmail, a shared Google Drive, and PayPal.me links. We replaced all of it with a self-hosted business stack on AWS in about an hour."
pubDate: 2026-05-16
tags: ["ShopStack", "small business", "case study", "infrastructure", "AWS"]
---

A friend of mine sells custom T-shirts. She's been doing it for a few years — takes orders through
Instagram DMs, sends payment requests via PayPal.me, emails proofs from her personal Gmail account,
and tracks orders in a Google Sheet.

It works, until it doesn't.

The Google Drive she uses for design files is also where her personal photos live. Her "business"
email is the same account she uses for everything else. When a customer asks for an invoice for
a bulk order, she screenshots her PayPal transaction history and sends that.

None of this is unusual. It's how most small businesses run in year one or two. But it has costs
that compound quietly: the credibility of a @gmail.com address on a business proposal, the confusion
of mixing personal and business files, the absence of any real paper trail.

I offered to set up a proper stack for her. She agreed to let me document it.

---

## What she needed

Before touching anything, I wrote down what I actually needed to solve:

1. **Professional email** — `@hertshirtbusiness.com`, not Gmail
2. **File storage** — Design files, vendor contacts, order history, separated from her personal life
3. **Invoicing** — Real invoices with a payment link, not PayPal screenshot PDFs
4. **Remote access** — A way for me to manage everything without her needing to be involved

That's it. No e-commerce platform, no CRM, no analytics. Those come later if the business grows.
Right now the goal is to stop looking like a hobbyist.

---

## The stack

I used [ShopStack](https://woodhead.tech/shopstack) — the same infrastructure I've packaged for
small business clients — deployed on AWS instead of a physical box.

Here's what got deployed:

| Service | What it does |
|---------|-------------|
| **Mailcow** | Email server. Handles SMTP/IMAP. Webmail at `mail.hertshirtbusiness.com`. |
| **Nextcloud** | Self-hosted file storage. Design files, order docs, vendor contacts. |
| **Invoice Ninja** | Invoicing + payment collection. Professional PDF invoices, Stripe integration. |
| **Authentik** | SSO. Protects all the admin interfaces behind a single login. |
| **Traefik** | Reverse proxy. Terminates TLS for every service via Cloudflare DNS-01. |
| **WireGuard** | VPN. How I access everything for maintenance without exposing admin ports. |
| **Uptime Kuma** | Status monitoring. I get alerted if anything goes down. |

Everything runs on a single `t3.large` EC2 instance (2 vCPU, 8 GB RAM) with a 40 GB gp3 volume.
Elastic IP so the DNS record never needs to change.

---

## The deployment

Infrastructure provisioning is Terraform. One `terraform apply` gives me an EC2 instance, an
Elastic IP, and a security group with the right ports open. Takes about 30 seconds.

After that it's Ansible. A single playbook deploys all eight services in order, handles TLS
certificate issuance through Cloudflare's DNS challenge, and configures each service to talk
to the others correctly.

```bash
terraform apply   # ~30 seconds
# set DNS A record in Cloudflare → Elastic IP
ansible-playbook shopstack.yml -i inventory.ini --become \
  --extra-vars "@profiles/aws.yml" \
  --extra-vars "@deploy-vars.yml"
```

The Ansible run handles everything: installing Docker, pulling images, writing configs,
wiring Traefik routes, waiting for health checks. No manual steps inside the instance.

**Total time from `terraform apply` to all services running: 57 minutes.**

That's not a benchmark I optimized for. It's just what the first run clocked on a cold instance
with no cached images. Most of that time is Mailcow pulling its 20-container image stack.

---

## What she got

When it was done, she had:

- `mail.hertshirtbusiness.com` — her own mail server with webmail and full SMTP/IMAP support.
  Thunderbird, Apple Mail, or any standard client works.
- `files.hertshirtbusiness.com` — Nextcloud. She can access design files from her phone, share
  order folders with vendors, and stop digging through a personal Drive.
- `billing.hertshirtbusiness.com` — Invoice Ninja. She creates invoices in under a minute.
  Customers get a link, pay by card, she gets a notification. No more PayPal screenshots.
- `status.hertshirtbusiness.com` — Uptime Kuma. A public status page so she (and I) can see
  if anything is down without logging in.

Every service is behind HTTPS with a real certificate. Every admin interface requires SSO login
through Authentik. She has one set of credentials for everything.

---

## What it costs

The AWS infrastructure runs about **$65/month** on-demand — the t3.large instance plus the
Elastic IP. That's the infrastructure cost.

On top of that, ShopStack's cloud management fee is **$79/month**, which covers:
- My time for monitoring and maintenance
- Updates and patching
- Support for adding or changing services
- The knowledge that if something breaks at 2am, I handle it, not her

All in: **~$144/month** for a complete business infrastructure stack, professionally managed.

That's less than most small businesses pay for a patchwork of SaaS tools that don't talk to
each other. And unlike those tools, she owns her data and her domain.

---

## What I learned deploying this

This was the first ShopStack deployment on AWS (my homelab clients run on physical hardware).
A few things came up:

**Mailcow's setup script is interactive by default.** It prompts for branch selection and
ClamAV configuration. On AWS, the IP is flagged by Spamhaus's ASN check, which causes
additional warnings. All of this is automatable — you just have to know to pass the right
environment variables. I updated the Ansible playbook to handle it.

**Authentik and Invoice Ninja both want port 9000.** Authentik runs internally on 9000 by
default. Invoice Ninja tried to bind the same host port. Moved Invoice Ninja to 9010.
Obvious in retrospect, the kind of thing you only know from running it.

**Invoice Ninja's container runs as UID 1500.** The storage directories need to be owned
by that UID before the container starts, or it crashes on first boot. The Ansible playbook
now handles this.

**Total playbook fixes from this deploy: 8.** All merged. The next client deployment
runs clean from the start.

---

## The point

I didn't build this to impress anyone. I built it because the gap between "running a real
business" and "running a hobbyist operation" is mostly infrastructure — and that gap is
smaller than most people think.

She now has the same professional stack a funded startup would have, running on hardware
she pays $65/month for instead of $500/month in SaaS sprawl. The difference is someone
who knows how to run it.

That's the whole ShopStack pitch. [See if it fits your business.](https://woodhead.tech/shopstack)
