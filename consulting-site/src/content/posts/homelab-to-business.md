---
title: "From Homelab to Business: How Running Your Own Infrastructure Changes What You Build"
description: "A decade of running production-equivalent infrastructure at home taught me things enterprise jobs couldn't. Then I turned it into a product. Here's the full story — the stack, the lessons, and how a lab becomes a business."
pubDate: 2026-05-15
tags: ["homelab", "ShopStack", "infrastructure", "engineering", "entrepreneurship"]
---

There's a gap between engineers who have read about infrastructure and engineers who have
operated it.

I don't mean "worked at a company that runs Kubernetes." I mean: been paged at 2am because
your own Ceph cluster's OSDs are writing to the wrong disk tier and you're watching NFS
latency climb in real time. Gone to bed after migrating a TrueNAS ZFS pool knowing the
backup job hasn't been verified in three weeks. Debugged a WireGuard handshake failure on
your own VPN at 11pm when you just wanted to finish watching something.

The homelab is where that gap closes.

This is the story of how I built mine, what it taught me, and how that infrastructure
eventually became a product I now sell to small businesses.

---

## What a homelab actually is

Not a gaming PC with too much RAM. Not a NAS with a Plex server. Those are fine, but
they're consumer setups.

A homelab, in the sense I mean it, is an environment where you run production-class
infrastructure with real operational responsibilities: certificate management, monitoring,
alerting, backups, networking, identity, secrets. The whole surface area. Everything that
breaks at the worst time.

The point isn't the hardware. The point is the responsibility. When you're the operator,
the engineer, and the on-call in the same person, you develop a very different relationship
with the systems you build.

You stop designing for the happy path. You start designing for 2am.

---

## The stack I built

My homelab runs on five physical machines:

- Three Lenovo ThinkCentre M900 Tiny nodes — compact, low-power, dense
- A mid-tower I built specifically for storage and Kubernetes control plane duties
- A Zotac CI329 mini PC handling additional K8s workers and home automation

Five machines run as a **Proxmox VE cluster** — the same hypervisor technology that
enterprise data centers use. Proxmox gives me live migration, high availability, and
cluster-aware resource scheduling. When I power down a node for maintenance, workloads
shift automatically.

Storage is a **Ceph distributed cluster** across the three ThinkCentres and the tower.
Six OSDs in total — three SSDs for performance, three HDDs for capacity — with 3x
replication. TrueNAS Scale runs as a VM backed by a Ceph RBD disk, presenting NFS shares
to containers and VMs that need shared storage. This is not far from how production
storage is architected at mid-size companies.

On top of that runs a **Talos Linux Kubernetes cluster** — four nodes, immutable OS,
declarative configuration only. No SSH access to the OS layer, no ad-hoc changes.
Everything via the API or it doesn't happen. MetalLB handles load balancer IP allocation.
ArgoCD handles GitOps deployment.

The network layer uses **Traefik** as a single ingress point for all services, with
automatic TLS certificate provisioning via Let's Encrypt and Cloudflare DNS challenge.
WireGuard handles remote management — every service is accessible through a VPN tunnel
with no exposed ports except 443 and 51820. Cloudflare DDNS keeps the homelab reachable
despite a residential IP address.

**Authentik** provides SSO for all protected services. One login, short session tokens,
MFA. Admin interfaces for every service require it.

The monitoring stack — **Prometheus, Grafana, and Alertmanager** — runs on a dedicated
LXC container. Dashboards are provisioned from code. Alert rules cover Ceph health, NFS
latency, container restarts, disk pressure, and memory thresholds. Discord webhook
notifications. A custom Prometheus exporter polls the Dexcom Share API for continuous
glucose data and alerts via Twilio if readings go out of range — a project born from a
personal health need, built on the same observability infrastructure as everything else.

Thirty-plus services. Everything from a media server to a Zigbee2MQTT broker for home
automation to a PXE boot server for provisioning new nodes. Two 3D printers — an Ender 5
Pro and an Ender 3 — each running Klipper with Mainsail, accessible via Traefik.

All of it is defined in code. Terraform provisions the Proxmox VMs and LXCs. Ansible
configures every service. Talos cluster configs are version-controlled. When I rebuild
from scratch — which I've done, intentionally, to verify the runbooks — the full stack
comes up from a git checkout.

---

## What running your own infrastructure teaches you

Here's what the homelab taught me that enterprise jobs couldn't.

### 1. You learn what actually breaks

In a large organization, there are enough people and enough process between you and the
infrastructure that most engineers never see the full failure mode of the systems they build on.
The on-call rotation is someone else's problem. The certificate expired and a different team
handled it. The backup job failed silently for three months and nobody noticed because restores
are the DR team's problem.

When it's your homelab, there is no other team. The Ceph OSD that's been running slow for
a week because it's hitting the HDD tier on writes? That's your problem. The NFS mount that
hangs when TrueNAS ZFS stalls under load? You're debugging it at 11pm. The WireGuard peer
that won't handshake because the endpoint resolves to a Cloudflare proxy IP instead of the
real homelab address? That's two hours of your Saturday.

You learn failure modes by failing. Not by reading about them.

### 2. You develop real opinions about toil

After the third time you've manually rotated a credential, or the fifth time you've SSH'd
into three boxes to check which one has the latest log, you stop tolerating toil. You
automate it. Not because someone told you to, but because you're personally tired of it.

That's a different motivation than "the team has decided to prioritize operational
efficiency." The engineers who have run their own infrastructure have felt toil personally.
They design systems differently because of it.

### 3. You understand that everything is networked

In a homelab, you handle networking yourself. Subnets, VLANs, DNS, DDNS, NAT, VPN. You
run into the WireGuard handshake that won't complete because your peer's endpoint is
resolving to a proxy that blocks UDP. You debug the Traefik route that's serving the wrong
backend because the Host header doesn't match. You discover why NFS over a residential
connection is a bad idea when latency spikes.

This knowledge is hard to acquire otherwise. Most cloud engineers have abstracted networking
so thoroughly that they've never had to think about it. When they do have to think about it,
they don't have the intuition to navigate it quickly.

### 4. You learn to respect what managed services actually do

After running Mailcow — a self-hosted email stack with Postfix, Dovecot, rspamd, and a
dozen moving parts — you gain a deep respect for Google Workspace. Not because Google is
doing something technically magical, but because keeping email working is genuinely hard,
and doing it at scale with spam filtering, deliverability monitoring, and DMARC compliance
is a real operational burden.

This is a valuable engineering perspective: knowing the real cost of what you've chosen
to run yourself versus what you've chosen to outsource. Most engineers don't have this
calibration. They either dismiss managed services entirely or use them without understanding
what problem they're actually solving.

### 5. You accumulate a portfolio of proof

Every service I've built, debugged, and operated is a conversation I can have with a
client. Not "I've read about Kubernetes." Not "I've used Kubernetes at my employer."
I've designed a cluster, provisioned it from scratch with Terraform and Talos, debugged
the Ceph slow-op cascades that caused NFS hangs at 2am, and written the runbook for
recovering the cluster if the etcd quorum is lost.

That's a different kind of credibility.

---

## The business insight

About two years into running the homelab, something shifted.

I'd been periodically helping family and friends with their business IT. A vet clinic
paying $80/month for Google Workspace for six people. A salon running on Gmail, Dropbox,
and a Squarespace site they couldn't update themselves. A small retail shop whose "IT
support" was calling Google's support line and waiting.

All of them had the same complaint: they were paying per-user SaaS fees that increased
every year, they had no one who would actually pick up the phone when something broke,
and they didn't own anything. Fifteen years of files in Dropbox. A domain registered in
a vendor's name. Email history in an account they couldn't easily move.

I looked at my homelab and saw the same stack these businesses needed — minus the 3D
printers and the Pwnagotchi.

Mailcow for email. Nextcloud for file storage. Traefik for routing. Cloudflare for DNS
and TLS. WireGuard for remote management. A PostgreSQL database as the foundation for
anything custom. Uptime Kuma for monitoring so I know before they do when something's off.

I'd already built it. I knew how to operate it. I knew what breaks and why. I had
runbooks. I had Ansible playbooks that could provision the entire stack from scratch.

The only thing missing was a customer.

---

## From homelab to product: ShopStack

I spent a weekend extracting the relevant parts of my homelab into a separate project.

The homelab infrastructure is general-purpose — it runs a Kubernetes cluster and an SDR
scanner and a Pwnagotchi and a Dexcom glucose alerting system. None of that is relevant
to a vet clinic.

I created a **small-business profile**: an Ansible playbook that deploys the exact
services a 1–15 person business needs, nothing else. Mailcow, Nextcloud, Invoice Ninja
with Stripe integration, Traefik, WireGuard, Uptime Kuma, PostgreSQL. Profiles for
three deployment targets: a Beelink EQ12 mini PC (on-premises), AWS EC2, and GCP
Compute Engine. Same playbook, different vars file.

The result is **ShopStack** — a managed business infrastructure stack for small businesses.

Here's how it works in practice:

**The hardware.** I recommend the Beelink EQ12 — a mini PC the size of a paperback, 16GB
RAM, 500GB NVMe SSD, fanless or near-silent, ~10W idle. About $200 on Amazon. It sits in
a back office and nobody thinks about it.

**The setup.** For the Plug & Play option, I configure the machine myself — domain, email,
file storage, invoicing, everything — test it, and ship it. The client plugs in ethernet
and power. That's it. For on-premises clients who want to supply their own hardware, I set
it up remotely. For clients who don't want hardware at all, the same stack runs on a
virtual server in AWS or GCP.

**The ongoing.** Monthly OS and software patching. Uptime Kuma monitoring with alerts to
me, not them. Backup monitoring. Up to one hour of support per month included. When
something breaks at 2am, I get paged — not them.

**The pricing.** $500–800 setup (depending on hardware option) plus $200–250/month.
No per-user fees. Month-to-month.

The financial case for a five-person business on Google Workspace is roughly $60/month
just for email. Add Squarespace ($25/month), Dropbox ($15/month), and you're at $100/month
before you've paid for invoicing software or anything custom. And every one of those
vendors has raised prices in the past three years.

ShopStack is $200/month for all of it. Flat. On hardware they own.

---

## The infrastructure code is the product

This is the part I want to be specific about, because it's where the homelab-to-business
translation is most direct.

My homelab is defined entirely in code. Terraform for provisioning. Ansible for
configuration. Every service, every route, every credential (sealed in Ansible Vault)
is in a git repository. Rebuilding the entire homelab from scratch takes time, but it
follows a documented process and results in the same end state.

ShopStack is the same discipline applied to a narrower scope.

The ShopStack Ansible playbook (`shopstack.yml`) runs eight roles in order:

```
postgres → traefik → authentik → wireguard →
mailcow → nextcloud → uptime-kuma → invoiceninja
```

Each role is idempotent. Running it twice produces the same result as running it once.
Each role accepts variables — the client's domain, their email accounts, their database
passwords — so the same playbook deploys a completely different client's stack without
any code changes.

This is the operational model that makes a managed service viable at small scale. One
person. Multiple clients. Consistent deployments. No snowflakes.

If I'd built ShopStack by hand-configuring each client's server — even following a
checklist — the maintenance would be unsustainable. Because the infrastructure is code,
adding a new client is running a playbook with new vars. Patching all clients is running
the same patch target against each inventory.

The homelab taught me this discipline because rebuilding the homelab from scratch and
having it fail due to configuration drift is personal pain. You develop the habits that
prevent configuration drift because you're the one debugging it at midnight.

---

## The broader principle: your lab is your portfolio; your product lives in your problem

I've described this as a ShopStack story, but the principle is more general.

**Your lab is your portfolio.** The work you do in your homelab is evidence of what you
can build. A running Kubernetes cluster with GitOps and observability is more compelling
than a line on a resume that says "experience with Kubernetes." The alertmind repo —
an AI alert triage tool I built in a weekend and deployed to my homelab's Alertmanager
stack — has done more for my consulting pipeline than any credential.

Show the running system. Show the code. Show the runbook. That's proof of work in the
original sense of the term.

**Your product lives in your problem.** I didn't start ShopStack by doing market research
on the small business IT space. I started it by helping people I knew who had a problem
I recognized, using infrastructure I'd already built for my own reasons. The best products
often come from this direction — from people who have deeply operated something and
recognize that the problem they've solved is a problem others have too.

This is different from "scratch your own itch," which implies building something you want
to use. It's more specific: build something you've been forced to understand at a deep
level because you've been running it yourself.

The engineers who have operated Ceph at home have a different instinct about distributed
storage than engineers who have only read about it. The engineers who have run their own
email server have a different sense of what managed email actually costs. That operational
depth is where good product decisions come from.

---

## What the homelab costs, and why it's worth it

The five physical machines in my homelab were acquired over several years, mostly used.
Total cost was somewhere around $1,500 in hardware. Power draw is roughly 150–200W at
peak load. At $0.12/kWh, that's $13–17/month in electricity.

The time investment is harder to quantify. Some months I spend ten hours on homelab
work — new projects, debugging, upgrades. Some months it runs with zero intervention.

What I've gotten in return: a decade of operational experience that maps directly to
what clients pay for in an engagement. The Ceph debugging I did on a Saturday morning
is directly relevant to a client whose distributed storage is degraded. The Traefik
configuration I've written dozens of times is something I can reproduce accurately
under deadline. The Kubernetes cluster I've bootstrapped from scratch is something I
can bootstrap for a client.

The homelab is professional development that runs 24/7.

---

## Starting

If you're an engineer thinking about building a homelab, the advice I'd give:

**Start with one machine.** A used ThinkCentre or HP EliteDesk costs $50–150 on eBay.
Install Proxmox. Run a few VMs. See what you learn.

**Operate something real.** Running a service you actually use — a DNS resolver,
a media server, an email server — creates the accountability that makes a homelab a
learning environment rather than a toy.

**Put it in code.** Even before you have the discipline of Ansible and Terraform, write
down every manual step you take. The documentation is the beginning of the automation.

**Let it break.** The Ceph cluster that degrades because you added a disk incorrectly
is more educational than a hundred hours of documentation. Don't intervene too quickly.
Understand what happened before you fix it.

**Build toward something.** The homelab shouldn't just be infrastructure for its own sake.
Build tools that run on top of it. The alertmind project came from being tired of raw
Alertmanager payloads. ShopStack came from recognizing that other people had the problem
I'd already solved. The lab is the foundation — build something on it.

---

The distance from a homelab to a business is shorter than it looks. What closes that
distance is operational depth — the kind you build by running real systems with real
consequences for a long time.

The homelab is how you get there.

---

*Brandon Woodward is a Systems Architect and AI Automation Consultant at
[woodhead.tech](https://woodhead.tech). He helps engineering teams cut manual ops and
integrate AI tooling that delivers real ROI. ShopStack — managed IT infrastructure
for small businesses — was built on the homelab infrastructure described in this post.
[Get in touch](/contact) if either sounds relevant.*
