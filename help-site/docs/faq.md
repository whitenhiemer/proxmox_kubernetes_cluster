---
sidebar_position: 9
title: FAQ
---

# Frequently Asked Questions

---

## General

### What is ShopStack?

ShopStack is a managed business system that includes email, file storage, and
invoicing — all running on your own hardware (or in the cloud), managed by
Woodhead Tech. You get professional tools without paying per-user SaaS fees.

### What's the difference between ShopStack and ShopStack Online?

**ShopStack** is for brick-and-mortar businesses — the system runs on a small computer
at your location (or in the cloud). It includes email, file storage, and invoicing.

**ShopStack Online** is for businesses that sell online. It includes everything in
ShopStack plus a WooCommerce online store.

### Who manages my system?

Brandon at Woodhead Tech manages your system. He monitors it 24/7 via the Uptime
Kuma dashboard and responds to support requests same-day on weekdays.

### Do I need to do anything to keep it running?

No. The system runs automatically and Brandon monitors it. If something breaks,
he'll know before you do and fix it.

You do need to:
- Create new staff email accounts when someone joins (or ask Brandon to do it)
- Keep your passwords safe
- Email brandon@woodhead.tech if something seems wrong

---

## Billing

### What does ShopStack cost?

| Plan | Setup | Monthly |
|------|-------|---------|
| ShopStack (On-Premises) | $500 | $200/mo |
| ShopStack (Plug & Play) | $800 | $200/mo |
| ShopStack (Cloud) | $300 | $250/mo |
| ShopStack Online | $99 | $99/mo |

Monthly billing starts after setup is complete.

### How am I billed?

You receive an invoice via Invoice Ninja (or email) on your billing date each month.
You can pay by credit card, debit card, or ACH via Stripe.

### What if I want to cancel?

Email brandon@woodhead.tech. There's no long-term contract — cancel any time.
If you're on the Plug & Play plan, you keep the hardware.

---

## Email

### Can I use my existing email on ShopStack?

Yes. ShopStack sets up email at your own domain (e.g., `you@yourbusiness.com`).
If you had email elsewhere before, Brandon will help migrate your existing emails
during setup.

### How many email addresses can I have?

As many as you need for your staff. There's no per-mailbox charge.

### Can I access my email on my phone?

Yes. See [Email client setup](/email/email-client-setup) for instructions.

---

## File Storage

### How much storage do I get?

For on-premises and Plug & Play clients: the Beelink EQ12 has a 500 GB NVMe drive.
You have the full drive minus OS and software overhead (~430 GB usable).

For cloud clients: the EC2 instance has a 40 GB disk by default. If you need more,
contact Brandon — disk size can be expanded.

### Can I share files with clients who don't have a Nextcloud account?

Yes. You can create a shareable link for any file or folder — no account needed
for the recipient. See [Sharing files](/files/sharing-files).

---

## Technical

### What happens if my system goes down?

Uptime Kuma monitors your system 24/7 and sends Brandon an alert if anything
stops responding. He'll investigate and fix it — usually before you notice.

If you notice something is down, email brandon@woodhead.tech immediately.

### Is my data backed up?

For cloud clients: AWS snapshots can be configured — contact Brandon to set this up.
For on-premises clients: your data lives on the hardware at your location. Contact
Brandon to discuss a backup solution.

### What happens if I need help that's not covered here?

Email brandon@woodhead.tech. If it's related to your ShopStack system, Brandon
will help. Support is included in your monthly fee for issues covered by the
managed service agreement. Significant customization work is quoted separately.

---

## Still have questions?

Email **brandon@woodhead.tech** or see the [Support page](/support).
