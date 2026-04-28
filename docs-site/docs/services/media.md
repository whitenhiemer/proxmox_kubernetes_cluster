---
sidebar_position: 4
title: Plex & Jellyfin
---

# Plex & Jellyfin

Plex: LXC 203 | `192.168.86.23` | Port 32400
Jellyfin: LXC 204 | `192.168.86.24` | Port 8096

Both share the TrueNAS NFS media library and Intel iGPU for hardware transcoding.

## Deploy

```bash
make plex
make jellyfin
```

## iGPU Passthrough

Both LXCs mount `/dev/dri` from the Proxmox host for Intel Quick Sync / VAAPI transcoding. They must run on the same node that has the iGPU.

- Plex: Settings > Transcoder > Enable hardware transcoding (Plex Pass required)
- Jellyfin: Dashboard > Playback > Transcoding > VAAPI, `/dev/dri/renderD128`

## NFS Media

```bash
cd ansible && ansible-playbook playbooks/setup-plex.yml \
  --extra-vars "nfs_server=192.168.86.40 nfs_share=/mnt/pool/media"
```

Libraries: `/media/movies`, `/media/tv`, `/media/music`
