---
sidebar_position: 4
title: Common Email Issues
---

# Common Email Issues

Solutions to the most frequent email problems.

---

## I can't log in to webmail

**Try this first:**
1. Go to `https://mail.YOUR_DOMAIN.woodhead.tech`
2. Your username is your full email address (e.g., `sarah@yourbusiness.com`)
3. Double-check the password — it's case-sensitive

**Still can't get in?**
Email brandon@woodhead.tech and include your email address. Brandon can reset your
password from the admin panel.

---

## My email client says "connection failed" or "authentication error"

1. Confirm the server address: `mail.YOUR_DOMAIN.woodhead.tech` (not `mail.yourdomain.com`)
2. Make sure you're using port **993** for incoming (IMAP) with SSL
3. Make sure you're using port **587** for outgoing (SMTP) with STARTTLS
4. Try logging in at the webmail URL first — if that works, the password is correct
5. If webmail also fails, email brandon@woodhead.tech

---

## I'm not receiving emails (they bounce or disappear)

This usually means someone is sending to the wrong address. Confirm with the sender
that they have your exact email address including the domain.

If emails are going to spam on the sender's end: this is a deliverability issue.
Email brandon@woodhead.tech with a description of who can't reach you — it may need
a DNS record adjustment.

---

## My emails are being marked as spam by recipients

If your outbound emails are landing in spam for others:

1. Make sure you're sending from your business email address, not a personal Gmail
2. Email brandon@woodhead.tech — this requires checking SPF, DKIM, and DMARC DNS records

Do not forward bulk messages or promotional content from your business mailbox.

---

## I can receive but not send email

1. Check that your SMTP server is `mail.YOUR_DOMAIN.woodhead.tech` on port **587**
2. Make sure STARTTLS (not SSL/TLS) is selected for the outgoing server
3. Confirm your password is correct by testing at the webmail URL
4. If the issue persists, email brandon@woodhead.tech

---

## I accidentally deleted an email

Check your **Trash** folder — deleted emails stay there for 30 days before being
permanently removed. In webmail, look for the Trash folder in the left sidebar.

If it's been more than 30 days or the Trash is empty, the email cannot be recovered.

---

## Still stuck?

Email **brandon@woodhead.tech** with:
- Your email address
- What you were trying to do
- What error message you saw (a screenshot helps)

Response target: same day on weekdays.
