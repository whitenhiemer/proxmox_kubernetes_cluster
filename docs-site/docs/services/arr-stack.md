---
sidebar_position: 3
title: ARR Stack
---

# ARR Media Stack

LXC 202 | `192.168.86.22` | Docker Compose

## Services

| Service | Port | Subdomain | Purpose |
|---|---|---|---|
| Prowlarr | 9696 | prowlarr.woodhead.tech | Indexer manager |
| Sonarr | 8989 | sonarr.woodhead.tech | TV show management |
| Radarr | 7878 | radarr.woodhead.tech | Movie management |
| Bazarr | 6767 | bazarr.woodhead.tech | Subtitle management |
| Seerr | 5055 | requests.woodhead.tech | User request portal |
| SABnzbd | 8080 | sabnzbd.woodhead.tech | Usenet downloader (via VPN) |
| Gluetun | -- | -- | WireGuard VPN killswitch for SABnzbd |

All services run as PUID=1000, PGID=1000 using LinuxServer.io images.

## Deploy

```bash
make arr-stack WG_PRIVATE_KEY=<privado_wireguard_private_key>
```

WireGuard key: download a `.conf` from my.privado.io and copy the `PrivateKey` field. The key is written to `/opt/arr/gluetun/wireguard_private_key` on the LXC and never committed to git.

## VPN Killswitch

SABnzbd runs inside gluetun's network namespace. All download traffic exits through PrivadoVPN WireGuard. If the VPN drops, SABnzbd loses connectivity entirely.

When restarting gluetun, always recreate SABnzbd at the same time — they share a network namespace:
```bash
docker compose up -d --force-recreate gluetun sabnzbd
```

## Configuration Order

1. Prowlarr — Add indexers
2. SABnzbd — Configure Usenet server
3. Sonarr — Connect to Prowlarr + SABnzbd
4. Radarr — Connect to Prowlarr + SABnzbd
5. Bazarr — Connect to Sonarr + Radarr
6. Seerr — Connect to Sonarr + Radarr

## Media Directory

```
/media/
├── downloads/
│   ├── complete/
│   └── incomplete/
├── movies/
├── tv/
├── music/
└── books/
```

NFS mounted from TrueNAS (192.168.86.40).
