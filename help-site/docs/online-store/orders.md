---
sidebar_position: 3
title: Managing Orders
---

# Managing Orders

When a customer places an order, you'll get an email notification. Manage all
orders from the WordPress admin panel.

**Admin panel:** `https://shop.YOUR_DOMAIN.woodhead.tech/wp-admin`

---

## View your orders

1. Log in to the admin panel
2. Click **WooCommerce** → **Orders** in the left sidebar
3. You'll see a list of all orders with status, customer name, and total

---

## Order statuses

| Status | Meaning |
|--------|---------|
| Pending payment | Order placed, payment not yet received |
| Processing | Payment received, needs to be fulfilled |
| Completed | Order has been fulfilled |
| Cancelled | Order was cancelled |
| Refunded | Payment has been refunded |
| On hold | Awaiting action (e.g., check payment pending) |

Most orders flow: **Pending payment** → **Processing** (when Stripe confirms payment) → **Completed** (when you fulfill it).

---

## Mark an order as complete

Once you've shipped or fulfilled an order:

1. Click the order number to open it
2. In the **Order status** dropdown (right side), change to **Completed**
3. Click **Update**

The customer automatically gets an email confirming their order is complete.

---

## Refund an order

1. Open the order
2. Click **Refund** (bottom of the page)
3. Enter the refund amount (partial or full)
4. Add a note if desired
5. Click **Refund via Stripe** — the refund is processed immediately

Stripe refunds go back to the customer's card within 5–10 business days.

---

## Add an order note

Useful for tracking what happened with an order or communicating with the customer.

1. Open the order
2. In the **Order notes** section (right side), type your note
3. Choose **Private note** (only you see it) or **Note to customer** (sends them an email)
4. Click **Add**

---

## Search for an order

In the Orders list, use the search bar or filter by:
- Customer name or email
- Order status
- Date range

---

## Questions?

Email brandon@woodhead.tech with the order number if you're having trouble with a specific order.
