---
sidebar_position: 3
title: Stripe Payments
---

# Stripe Payments

Connect Stripe to accept credit card, debit card, and ACH payments directly from
your invoices. Clients click **Pay Now** on the invoice and pay online.

---

## Before you start

You'll need a Stripe account. If you don't have one:
1. Go to **stripe.com** and sign up (free)
2. Complete Stripe's identity verification
3. Add a bank account to receive payouts

Stripe charges **2.9% + 30¢** per successful card charge. There's no monthly fee.
Payouts go to your bank account on a 2-day rolling basis.

---

## Connect Stripe to Invoice Ninja

1. Log in to your invoicing panel at `https://billing.YOUR_DOMAIN.woodhead.tech`
2. Click **Settings** (gear icon) → **Payment Gateways**
3. Click **+ Add Gateway** → select **Stripe**
4. Click **Connect with Stripe**
5. You'll be redirected to Stripe — log in and authorize the connection
6. You'll be sent back to Invoice Ninja automatically

Stripe is now connected. Your invoices will show a **Pay Now** button.

---

## Test it

Before sending to a real client, test the payment flow:

1. Create a test invoice to yourself (use your own email)
2. Click the payment link in the email you receive
3. Use Stripe's test card: `4242 4242 4242 4242`, any future expiry, any 3-digit CVC
4. Click **Pay Now** — the invoice should update to "Paid"

If it works, you're set.

---

## Receiving payouts

Stripe pays out to your bank account automatically. Payouts are typically processed
within 2 business days of a payment.

To check payout status:
1. Log in to **dashboard.stripe.com**
2. Click **Balance** in the left sidebar
3. You'll see pending and available balances, and upcoming payout dates

---

## Stripe fees and receipts

Stripe sends your customers an automatic receipt after every payment.

You can view every transaction in the Stripe dashboard under **Payments**.

For tax purposes, Stripe provides a monthly summary and a 1099-K at year-end if
you process over $600.

---

## Questions about Stripe?

Stripe has extensive help documentation at **support.stripe.com**.

For issues connecting Stripe to your invoicing system, email brandon@woodhead.tech.
