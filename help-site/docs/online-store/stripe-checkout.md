---
sidebar_position: 4
title: Stripe Checkout
---

# Stripe Checkout

Your online store accepts payments through Stripe — credit cards, debit cards,
and Apple Pay/Google Pay (on supported devices).

Stripe was set up by Brandon during your onboarding. This page covers what you
need to know to use it day-to-day.

---

## How customers pay

When a customer checks out:

1. They click **Proceed to Checkout** on the cart page
2. They fill in their shipping and contact info
3. They enter their card details on the Stripe-hosted payment page
4. Payment is processed automatically — they get an order confirmation email

You get an email notification and the order appears in your admin panel as
**Processing**.

---

## View your Stripe balance and payouts

Log in to **dashboard.stripe.com** with your Stripe account.

- **Payments** tab — every transaction with status and amount
- **Balance** tab — your current balance and next payout date
- **Payouts** — history of transfers to your bank account

Stripe pays out to your bank account on a rolling 2-day basis (or 7-day for new accounts).

---

## Issue a refund

See [Managing Orders](/online-store/orders#refund-an-order) — refunds are processed
directly from the order in your admin panel.

---

## Test your checkout

To make sure checkout works without charging a real card:

1. Add a product to your cart and proceed to checkout
2. Use Stripe's test card: `4242 4242 4242 4242`
3. Any future expiry date, any 3-digit CVC, any billing ZIP
4. Complete the order — it should go through as a test payment

Test payments appear in your Stripe dashboard under **Payments** with a "Test" badge.

---

## Stripe fees

Stripe charges **2.9% + 30¢** per successful card transaction. This is deducted
before payout — your Stripe balance shows the net amount after fees.

There is no monthly fee for using Stripe.

---

## Questions?

- **Stripe account issues:** support.stripe.com
- **Checkout not working on your store:** email brandon@woodhead.tech
