---
sidebar_position: 1
title: Traefik
---

# Traefik Reverse Proxy

LXC 200 | `192.168.86.20` | Ports 80, 443

Central reverse proxy and TLS terminator for all `*.woodhead.tech` services.

## Architecture

- Runs as a native binary (not Docker) on a Debian LXC
- Wildcard TLS via Let's Encrypt DNS-01 challenge (Cloudflare API)
- Certificate stored in `/etc/traefik/acme.json`
- Dynamic routes in `/etc/traefik/dynamic/` (hot-reloaded)

## Deploy

```bash
make traefik
```

## Routing

Routes are defined in `ansible/files/traefik/dynamic/*.yml`. Traefik watches the directory and hot-reloads on change.

Services behind Authentik SSO use the `authentik@file` middleware.

## Verify

```bash
ssh root@192.168.86.20 "traefik version"
curl -I https://recipes.woodhead.tech
```
