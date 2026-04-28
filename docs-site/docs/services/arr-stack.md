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
| Overseerr | 5055 | requests.woodhead.tech | User request portal |
| SABnzbd | 8080 | sabnzbd.woodhead.tech | Usenet downloader |
| Gluetun | -- | -- | VPN tunnel for downloads |

All services run as PUID=1000, PGID=1000 using LinuxServer.io images.

## Deploy

```bash
make arr-stack

# With NFS media from TrueNAS
cd ansible && ansible-playbook playbooks/setup-arr-stack.yml \
  --extra-vars "nfs_server=192.168.86.40 nfs_share=/mnt/tank/media"
```

## Configuration Order

1. Prowlarr -- Add indexers
2. SABnzbd -- Configure Usenet server
3. Sonarr -- Connect to Prowlarr + SABnzbd
4. Radarr -- Connect to Prowlarr + SABnzbd
5. Bazarr -- Connect to Sonarr + Radarr
6. Overseerr -- Connect to Sonarr + Radarr
7. Gluetun -- VPN provider credentials

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
