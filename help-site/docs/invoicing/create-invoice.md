---
sidebar_position: 2
title: Create an Invoice
---

# Create an Invoice

Step-by-step guide to creating and sending your first invoice.

**Your invoicing panel:** `https://billing.YOUR_DOMAIN.woodhead.tech`

---

## Step 1 — Add your client

Before creating an invoice, add the client to your contacts.

1. Click **Clients** in the left sidebar
2. Click **New Client**
3. Fill in:
   - **Name** — client's name or business name
   - **Email** — where the invoice will be sent
   - **Address** — optional, appears on the invoice
4. Click **Save**

You only need to do this once per client. After that, select them from your contacts
when creating invoices.

---

## Step 2 — Create the invoice

1. Click **Invoices** in the left sidebar
2. Click **New Invoice**
3. Select the client from the dropdown (or type their name)
4. The invoice date and due date fill in automatically — adjust if needed
5. Under **Line Items**, add what you're billing for:
   - **Product/Service** — what you provided
   - **Description** — optional detail
   - **Quantity** — how many hours, units, etc.
   - **Unit Cost** — price per unit
6. The total calculates automatically
7. Add a note in the **Terms** field if needed (e.g., "Thank you for your business!")

---

## Step 3 — Send the invoice

1. Click **Send Email** (or **More Actions** → **Email Invoice**)
2. The email preview shows what your client will receive — it includes a link to view and pay the invoice online
3. Click **Send**

Your client gets an email with a link to view the invoice. If Stripe is connected,
the invoice page will show a **Pay Now** button.

---

## Track invoice status

In the **Invoices** list, each invoice shows its status:

| Status | Meaning |
|--------|---------|
| Draft | Not yet sent |
| Sent | Sent but not paid |
| Viewed | Client opened the invoice |
| Partial | Partial payment received |
| Paid | Fully paid |
| Overdue | Past due date, not paid |

Click any invoice to see its full history — sent time, opened time, payment received.

---

## Send a payment reminder

For overdue invoices:

1. Click the invoice
2. Click **More Actions** → **Remind**
3. The client gets a reminder email with the same payment link

---

## Mark an invoice as paid (for cash or check payments)

If a client pays you outside of Stripe:

1. Click the invoice
2. Click **Enter Payment**
3. Enter the amount and payment method (cash, check, etc.)
4. Click **Save**

The invoice is marked paid in your records.

---

## Download a PDF copy

1. Click the invoice
2. Click **More Actions** → **Download PDF**

The PDF looks the same as what your client receives.
