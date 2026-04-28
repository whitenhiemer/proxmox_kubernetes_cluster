---
sidebar_position: 8
title: Authentik SSO
---

# Authentik Identity Provider

LXC 207 | `192.168.86.28` | Port 9000 | `auth.woodhead.tech`

Single sign-on via Google OAuth for all protected services.

## Architecture

```
Client -> Traefik -> forwardAuth middleware -> Authentik
                                                |
                                          Google OAuth2
                                                |
                                          Session cookie
                                                |
Client -> Traefik -> forwardAuth (valid) -> Backend service
```

## Deploy

```bash
make authentik
```

## Protected Services

Services with `authentik@file` middleware in their Traefik dynamic config require authentication:

- Prometheus, Alertmanager
- Prowlarr, Sonarr, Radarr, Bazarr, Overseerr, SABnzbd
- NAS (TrueNAS)
- Scanner (rdio-scanner)
- Traefik dashboard

## Access Control Groups

- **admins** -- full access to all services
- **media-users** -- access to Overseerr, Plex, Jellyfin

## Verify

```bash
curl -I https://auth.woodhead.tech
```
