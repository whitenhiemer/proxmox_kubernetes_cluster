---
sidebar_position: 4
title: Recurring Invoices
---

# Recurring Invoices

Set up recurring invoices to bill clients automatically on a schedule — monthly,
weekly, quarterly, or annually.

---

## Create a recurring invoice

1. Log in to `https://billing.YOUR_DOMAIN.woodhead.tech`
2. Click **Recurring Invoices** in the left sidebar
3. Click **New Recurring Invoice**
4. Select the client
5. Add line items (same as a regular invoice)
6. Set the schedule:
   - **Frequency** — how often to send (Monthly, Weekly, Quarterly, Annually)
   - **Start date** — when to send the first invoice
   - **End date** — optional, leave blank to run indefinitely
7. Under **Auto Bill**, choose:
   - **Always** — automatically charges the client's saved card (requires Stripe + saved payment method)
   - **Off** — sends the invoice by email for the client to pay manually
8. Click **Save**

---

## How it works

On the scheduled date, Invoice Ninja automatically:
1. Creates a new invoice for that billing period
2. Sends it to the client by email (with the same **Pay Now** link as a regular invoice)
3. If Auto Bill is on and the client has a saved card, charges the card automatically

You'll get an email notification each time a recurring invoice is sent or paid.

---

## View and manage recurring invoices

Click **Recurring Invoices** in the sidebar to see all active schedules.

From this list you can:
- **Pause** a recurring invoice (stops sending until you unpause)
- **Stop** a recurring invoice (ends the schedule permanently)
- **Edit** the invoice details or schedule

---

## Save a client's payment method (for auto-billing)

For Auto Bill to work, the client needs to have a saved card on file.

The easiest way: send a regular invoice first and ask the client to check "Save
payment method" when they pay. Their card will be saved for future auto-billing.

Or, contact brandon@woodhead.tech to set up a Stripe payment link specifically for
saving a card on file.

---

## Questions?

Email brandon@woodhead.tech.
