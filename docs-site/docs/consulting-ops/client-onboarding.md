---
sidebar_position: 3
title: Client Onboarding
---

# ShopStack Client Onboarding Runbook

Human-executable. No AI required. Covers the full client lifecycle from first contact
to a live, handed-off stack with a satisfied client.

**Total elapsed time (typical):** 5–10 days from signed contract to client live
**Your active time:** ~4 hours (discovery call + deploy + handoff call)

---

## Stage 1 — Qualify the Lead

When a lead comes in (Cal.com booking, Facebook message, LinkedIn DM, email):

**Questions to answer before spending time on a proposal:**

1. Do they have a real business with real revenue? (Not a side project or "idea")
2. Are they currently paying for something ShopStack replaces? (Gmail, Google Workspace, PayPal, Dropbox, QuickBooks — any of these is a yes)
3. Do they have a domain, or are they open to getting one?
4. Is it a brick-and-mortar / service business (ShopStack) or online-only seller (ShopStack Online)?

**Red flags — pass politely:**
- "I just need a website" — not our product
- "Can you do this for $50/mo?" — price shoppers who'll churn
- Under 1 year in business — usually no budget, too much hand-holding
- No current tech spend at all — long sales cycle, not worth it at this stage

**Green flags — move fast:**
- Currently paying $100+/mo in fragmented tools
- Owner is frustrated with their current setup
- They already understand email and file storage — just don't want to manage it

---

## Stage 2 — Discovery Call (30 min)

Use the intake form: `~/WOODHEAD_CONSULTING/onboarding/shopstack-intake-form.md`

Fill it out during or immediately after the call. Don't skip fields — missing info
causes delays later.

**Key things to nail down before hanging up:**
- Which tier (On-Prem, Plug & Play, Cloud, or Online)?
- Their domain name and who controls the DNS?
- How many staff need email?
- Do they have Stripe or need help setting it up?
- Shipping address (Plug & Play only)?
- Is 50% upfront workable for them today?

At the end of the call: "I'll send over a proposal within 24 hours. If it looks good,
we can get started the same day you sign."

---

## Stage 3 — Send Proposal (within 24 hours of call)

Template: `~/WOODHEAD_CONSULTING/proposals/sample-vetclinic-plugandplay.html`

**Customize:**
1. Open the HTML file — edit client name, date, reference number, tier and pricing
2. Export to PDF: `google-chrome --headless=new --print-to-pdf=Proposal-CLIENTNAME-DATE.pdf --no-pdf-header-footer "file://$(pwd)/sample-vetclinic-plugandplay.html"`
3. Send using cover email template: `~/WOODHEAD_CONSULTING/proposals/sample-vetclinic-cover-email.md`
   - Swap out client name, tier, pricing, and expiry date (30 days from today)

**Pricing reference:**

| Tier | Setup | Monthly |
|------|-------|---------|
| On-Premises (client orders hardware) | $500 | $200/mo |
| Plug & Play (hardware included) | $800 | $200/mo |
| Cloud (AWS, no hardware) | $300 | $250/mo |
| ShopStack Online (WooCommerce, cloud) | $99 | $99/mo |

50% upfront on all engagements. Remainder due at handoff.

---

## Stage 4 — Contract + Payment

**When client says "let's go":**

1. Send contract: `~/WOODHEAD_CONSULTING/contract-template.md`
   - Fill in: client legal name, address, effective date, services description (Exhibit A), total fee
   - Docusign, HelloSign, or PDF + email scan — whatever the client prefers
   - Both parties sign before work starts

2. Invoice the 50% setup fee via Stripe:
   - Log in to Stripe dashboard
   - Create invoice → add line item (e.g., "ShopStack Plug & Play — Setup Fee") → send
   - Do NOT start deployment until payment clears

3. Once payment clears in Stripe: send kickoff email (Stage 5)

---

## Stage 5 — Kickoff Email + Info Collection

Template: `~/WOODHEAD_CONSULTING/proposals/sample-vetclinic-kickoff-email.md`

Collect before starting deployment:

| Item | Why needed |
|------|-----------|
| Domain name | DNS setup, TLS certs, email routing |
| DNS registrar login (if migrating to Cloudflare) | Point DNS to ShopStack |
| Staff name + email handle list | Mailcow mailbox creation |
| Shipping address | Plug & Play hardware shipment |
| Stripe account email (or "not yet") | Invoice Ninja payment gateway |
| Business logo (PNG or SVG) | Invoice Ninja branding |

**Do not start deployment until you have at minimum:** domain name + staff list.
Shipping address needed before ordering hardware (Plug & Play).

For Plug & Play: order Beelink EQ12 from Amazon once payment clears and shipping
address is confirmed. Delivery is typically 2–3 days. Configure it while it's in transit.

---

## Stage 6 — Deploy

Follow the deployment runbook: [ShopStack Deployment](./shopstack-deployment)

**Path selection:**
- Cloud or ShopStack Online → Path A (AWS)
- On-Premises or Plug & Play → Path B (On-Premises)

Do not proceed to Stage 7 until all service URLs are verified and the WireGuard
spoke is connected.

---

## Stage 7 — Initial Service Configuration

Complete before the handoff call. Client should log in to a working system, not a wizard.

### Mailcow

SSH to box or use `https://mail.CLIENT_SLUG.woodhead.tech`:

- [ ] Create client's mail domain (e.g., `pawsandclover.com`)
- [ ] Create one mailbox per staff member (from kickoff email list)
- [ ] Create any shared aliases (info@, appointments@, billing@)
- [ ] Send a test email from `brandon@woodhead.tech` → confirm it arrives
- [ ] Send a test email from a staff mailbox → confirm it sends

### Invoice Ninja

Browse to `https://billing.CLIENT_SLUG.woodhead.tech` and complete first-run wizard:

- [ ] Admin account: use client's primary email, generate a strong password
- [ ] Company name, address, phone, logo (upload their PNG)
- [ ] Currency: USD
- [ ] If client has Stripe: Settings → Payment Gateways → Add Stripe → enter their API keys
- [ ] Create a test invoice to yourself → confirm payment link renders

### Nextcloud

Browse to `https://files.CLIENT_SLUG.woodhead.tech`:

- [ ] Log in as admin (password from `nextcloud_admin_pass` in deploy-vars.yml)
- [ ] Create a user account for each staff member
- [ ] Create a shared folder structure (e.g., `Shared / Invoices / Clients`)
- [ ] Send each staff member their login credentials

### Uptime Kuma

Browse to `https://status.CLIENT_SLUG.woodhead.tech`:

- [ ] Add monitors for each client-facing service URL
- [ ] Set notification channel to your email (brandon@woodhead.tech)

### WooCommerce (ShopStack Online only)

Browse to `https://shop.CLIENT_SLUG.woodhead.tech/wp-admin`:

- [ ] Log in (wp_admin_user / wp_admin_pass from deploy-vars.yml)
- [ ] Complete WooCommerce setup wizard (store country, currency, shipping zones)
- [ ] Add Stripe payment gateway: WooCommerce → Payments → Stripe → enable → enter keys
- [ ] Install a product listing for the client (or leave for them to do on handoff call)

---

## Stage 8 — Handoff Call (30 min)

Schedule this call before deployment starts — book it in the kickoff email or
immediately after. Client should be at their computer.

**Agenda:**

1. Walk through each service URL together (screen share)
2. Have them log in to email from their phone or computer — confirm it works
3. Show them how to send an invoice in Invoice Ninja
4. Show them Nextcloud — add a file together
5. Explain Uptime Kuma: "This monitors your system 24/7. If anything goes down I get alerted before you do."
6. Set up their Stripe account together if not done yet
7. Answer questions

**At end of handoff call:**
- Invoice the remaining 50% via Stripe — do it on the call so they see it
- Confirm their preferred support contact method (email / text)
- Set expectation: "For any issues, email brandon@woodhead.tech. I target same-day response on weekdays."
- Ask: "Would you be open to being featured in a short case study once you've been running on this for 30 days?" — plant the seed now

---

## Stage 9 — 30-Day Check-In

Schedule this before hanging up on the handoff call. Calendar invite, 15 min.

**Purpose:** make sure everything is still working, build the relationship, collect the case study.

**Agenda:**

1. "How's it going? Any issues?" — if yes, fix on the spot
2. Review Uptime Kuma — confirm no incidents in the first 30 days
3. "Are you actively using Nextcloud / Invoice Ninja / email?"
4. If yes to all → ask for the case study:
   > "I'd love to write a short case study about your setup — nothing fancy, just a paragraph about what you were using before, what you use now, and whether it's saving you time. I'd feature it on woodhead.tech. Would that be okay?"
5. If they agree: ask 3 questions, write the case study yourself (they'll approve it)

**Case study questions:**
- "What were you using for email and billing before ShopStack?"
- "What problem was that causing?"
- "What's the biggest change since switching?"

---

## Checklist Summary

| Stage | Action | Done |
|-------|--------|------|
| 1 | Qualify lead — confirm ICP fit | ☐ |
| 2 | Discovery call — fill intake form | ☐ |
| 3 | Send proposal within 24 hrs | ☐ |
| 4 | Contract signed + 50% payment cleared | ☐ |
| 5 | Kickoff email sent + info collected | ☐ |
| 6 | Deployment complete — all URLs verified | ☐ |
| 7 | Mailcow, Invoice Ninja, Nextcloud configured | ☐ |
| 8 | Handoff call done — remaining 50% invoiced | ☐ |
| 9 | 30-day check-in scheduled | ☐ |
| 9 | Case study requested | ☐ |
