---
sidebar_position: 6
title: WireGuard VPN
---

# WireGuard VPN

LXC 208 | `192.168.86.39` | UDP 51820

Secure remote access to the entire homelab LAN.

## Architecture

```
Phone/Laptop (remote)
    |
    | WireGuard tunnel (UDP 51820)
    v
ISP Modem -> Google Nest (port forward UDP 51820)
    |
    v
WireGuard LXC (192.168.86.39)
    |
    | IP forwarding + masquerade
    v
192.168.86.0/24 (full LAN access)
```

## VPN Subnet

- `10.10.0.1` -- WireGuard server
- `10.10.0.2` -- Brandon's laptop
- `10.10.0.3` -- Brandon's phone
- `10.10.0.4+` -- additional clients

## Deploy

```bash
make wireguard
```

Forward UDP 51820 in Google Home app -> `192.168.86.39:51820`.

## Client Setup

Client configs generated at `/etc/wireguard/clients/` on the LXC, fetched to `ansible/files/wireguard/clients/` locally. Import `.conf` into the WireGuard app.

## Verify

```bash
ssh root@192.168.86.39 "wg show"
ping 10.0.0.1  # From client
```
