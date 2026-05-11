---
sidebar_position: 13
title: Libby Alert
---

# Libby Alert

LXC 209 | `192.168.86.27` | Port 80 | [libby.woodhead.tech](https://libby.woodhead.tech)

Life alert QR-code website. A static page with a prominent QR code that, when scanned, triggers SMS and Discord alerts to notify family members of an emergency.

## Architecture

- Static HTML/CSS site served by Nginx on port 80
- QR code links to a trigger endpoint that fires alerts via Twilio SMS and/or Discord webhook
- Alert cooldown prevents duplicate notifications within a configurable window

```
QR Code (physical card / printed page)
    |  Scan
    v
libby.woodhead.tech (Traefik -> LXC 209)
    |
    +---> Twilio SMS -> Alert phones
    +---> Discord webhook -> Channel notification
```

## Deploy

```bash
# Provision the LXC
make apply-lxc

# Deploy with both Twilio and Discord alerts
make libby-alert \
  TWILIO_SID=ACxxx \
  TWILIO_TOKEN=xxx \
  TWILIO_FROM=+1xxxxxxxxxx \
  ALERT_PHONES=+1xxxxxxxxxx,+1xxxxxxxxxx \
  DISCORD_WEBHOOK=https://discord.com/api/webhooks/...

# Deploy with Discord only
make libby-alert DISCORD_WEBHOOK=https://discord.com/api/webhooks/...

# Optional: set cooldown in minutes (default: 5)
make libby-alert ... COOLDOWN=10
```

## Verify

```bash
# Check site is reachable
curl -s https://libby.woodhead.tech | grep -c "QR"

# Check Nginx
ssh root@192.168.86.27 'systemctl status nginx'
```

## Troubleshooting

- **SMS not sending**: Verify Twilio credentials in `/opt/libby-alert/.env` and confirm the Twilio account has a verified number.
- **Discord alert not firing**: Check the webhook URL; Discord webhooks expire if unused.
- **Cooldown too aggressive**: Adjust `ALERT_COOLDOWN_MINUTES` in the `.env` file and restart the service.
