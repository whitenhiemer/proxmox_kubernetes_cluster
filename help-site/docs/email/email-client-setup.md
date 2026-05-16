---
sidebar_position: 2
title: Email Client Setup
---

# Email Client Setup

You can use your business email in any standard email app. This page covers the
most common options.

**Your email settings (you'll need these for all setups):**

| Setting | Value |
|---------|-------|
| Email address | yourname@yourdomain.com |
| IMAP server | mail.YOUR_DOMAIN.woodhead.tech |
| IMAP port | 993 (SSL) |
| SMTP server | mail.YOUR_DOMAIN.woodhead.tech |
| SMTP port | 587 (STARTTLS) |
| Username | yourname@yourdomain.com |
| Password | Your mailbox password (from Brandon's handoff email) |

:::tip
Your exact server address (the `YOUR_DOMAIN` part) was included in the handoff
email. If you're not sure, email brandon@woodhead.tech.
:::

---

## Outlook (Windows or Mac)

1. Open Outlook → **File** → **Add Account**
2. Enter your email address and click **Connect**
3. If Outlook doesn't auto-detect the settings, choose **IMAP** manually
4. Enter the IMAP and SMTP settings from the table above
5. Click **Connect** — enter your password when prompted
6. Your inbox will appear in the left sidebar

**Outlook mobile (iOS/Android):**
1. Open the Outlook app → tap your profile icon → **Add Email Account**
2. Enter your email address and tap **Continue**
3. Choose **IMAP** if prompted
4. Enter server settings from the table above
5. Tap **Sign In**

---

## Apple Mail (Mac)

1. Open Mail → **Mail** menu → **Add Account**
2. Choose **Other Mail Account** → click **Continue**
3. Enter your name, email address, and password
4. Click **Sign In**
5. If it fails to auto-detect, enter the IMAP/SMTP settings manually using the table above
6. Select **Mail** (and Contacts/Calendar if desired) → click **Done**

**Apple Mail (iPhone/iPad):**
1. Go to **Settings** → **Mail** → **Accounts** → **Add Account**
2. Tap **Other** → **Add Mail Account**
3. Enter your name, email, password, and a description
4. Tap **Next** — select **IMAP**
5. Fill in the incoming and outgoing server settings from the table above
6. Tap **Next** → **Save**

---

## Gmail App (Android or iPhone)

The Gmail app can send and receive from non-Gmail accounts.

1. Open the Gmail app → tap the menu (≡) → **Settings**
2. Tap **Add account** → **Other**
3. Enter your email address → tap **Next**
4. Choose **Personal (IMAP)**
5. Enter your password
6. For incoming server: use settings from the table above
7. For outgoing (SMTP) server: use settings from the table above
8. Tap **Next** → **Next** → give the account a name

---

## Thunderbird (Windows, Mac, Linux)

1. Open Thunderbird → click the menu (≡) → **New** → **Existing Email**
2. Enter your name, email address, and password → click **Continue**
3. Thunderbird will try to auto-detect settings — if it finds IMAP, confirm and click **Done**
4. If auto-detect fails, click **Manual Config** and enter:
   - Incoming: IMAP, server from table, port 993, SSL/TLS
   - Outgoing: SMTP, server from table, port 587, STARTTLS
5. Click **Done**

---

## Can't connect?

If you get a connection error or authentication failure:

1. Double-check the server address — it should be `mail.YOUR_DOMAIN.woodhead.tech`, not `mail.yourdomain.com`
2. Confirm your password is correct — try logging in at the webmail URL first
3. Make sure port 993 (IMAP) and 587 (SMTP) aren't blocked by your network or firewall
4. Email brandon@woodhead.tech if you're still stuck — include a screenshot of the error
