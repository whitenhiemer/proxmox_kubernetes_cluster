# Roadmap

Future services and infrastructure planned for the Proxmox homelab.

## Planned Services

### NAS (TrueNAS Scale)

**Type**: Proxmox VM (not LXC -- needs direct disk access)
**Domain**: `nas.woodhead.tech`
**Why VM**: TrueNAS Scale needs direct disk passthrough for ZFS pool management.
LXC containers can't do raw disk passthrough safely.

**Requirements**:
- Dedicated disks (NOT on the Ceph pool) passed through to the VM
- Minimum 8GB RAM (more for ZFS ARC cache -- 1GB per TB of storage is ideal)
- 2-4 CPU cores
- Proxmox disk passthrough via `qm set <vmid> -scsi1 /dev/disk/by-id/<disk-id>`

**Shares**:
- SMB/NFS exports for media, backups, ISOs
- Media share mounted by Plex, Jellyfin, and ARR stack containers

**Terraform**: `terraform/vm-truenas.tf` (VM ID: 300)
**Traefik route**: `nas.woodhead.tech` -> TrueNAS web UI (:443)

**Notes**:
- TrueNAS Scale is Debian-based and includes built-in app support (K8s under the hood)
- However, we'll use it purely as a NAS -- apps run on our own K8s cluster or LXCs
- Consider separate network interface (VLAN) for storage traffic if bandwidth is a concern

---

### ARR Stack

**Type**: LXC container with Docker Compose (or K8s workloads)
**Domain**: `*.woodhead.tech` subdomains per service

**Services**:
| Service   | Purpose                          | Port  | Subdomain                   |
|-----------|----------------------------------|-------|-----------------------------|
| Prowlarr  | Indexer manager                  | 9696  | `prowlarr.woodhead.tech`    |
| Sonarr    | TV show management               | 8989  | `sonarr.woodhead.tech`      |
| Radarr    | Movie management                 | 7878  | `radarr.woodhead.tech`      |
| Bazarr    | Subtitle management              | 6767  | `bazarr.woodhead.tech`      |
| Lidarr    | Music management (optional)      | 8686  | `lidarr.woodhead.tech`      |
| Readarr   | Book management (optional)       | 8787  | `readarr.woodhead.tech`     |
| Overseerr | Request management (user-facing) | 5055  | `requests.woodhead.tech`    |
| SABnzbd   | Usenet downloader                | 8080  | `sabnzbd.woodhead.tech`     |

**Recommended approach**: Single LXC with Docker Compose. The ARR apps are tightly
coupled (they talk to each other via localhost) and benefit from shared filesystem
access to the media library. Docker Compose keeps them manageable as a unit.

**Requirements**:
- 2-4 CPU cores, 4GB RAM, 20GB disk (downloads go to NAS)
- NFS/SMB mount from TrueNAS for media storage
- VPN container (gluetun) for download clients if needed

**Terraform**: `terraform/lxc-arr.tf` (VM ID: 202)
**Traefik routes**: `ansible/files/traefik/dynamic/arr-stack.yml`

**Directory structure on NAS**:
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

---

### Home Assistant

**Type**: Proxmox VM (HAOS -- Home Assistant OS)
**Domain**: `home.woodhead.tech`
**Why VM**: Home Assistant OS (HAOS) is the recommended install method. It's a
purpose-built OS with addon support, automatic backups, and OTA updates. Running
as a container loses addon support and complicates USB device passthrough.

**Requirements**:
- 2 CPU cores, 2GB RAM, 32GB disk
- USB passthrough for Zigbee/Z-Wave dongles (if used):
  `qm set <vmid> -usb0 host=<vendor>:<product>`
- HAOS qcow2 image imported to Proxmox (not ISO -- it's a pre-built disk image)

**Installation**:
```bash
# Download HAOS for Proxmox
wget https://github.com/home-assistant/operating-system/releases/download/<version>/haos_ova-<version>.qcow2.xz

# Import to Proxmox
qm importdisk <vmid> haos_ova-<version>.qcow2 <storage>
```

**Terraform**: `terraform/vm-homeassistant.tf` (VM ID: 301)
**Traefik route**: `home.woodhead.tech` -> HA web UI (:8123)

**Notes**:
- HAOS manages its own updates -- don't put it behind package management
- Backup integration with TrueNAS (NFS share for HA backups)
- Consider a dedicated VLAN for IoT devices (security isolation)

---

### Plex Media Server

**Type**: LXC container (or K8s pod)
**Domain**: `plex.woodhead.tech`

**Requirements**:
- 2-4 CPU cores, 4GB RAM, 20GB disk (media on NAS)
- Hardware transcoding: Intel iGPU passthrough for Quick Sync
  - LXC: mount `/dev/dri` into the container
  - Add to LXC config: `lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir`
  - Add `lxc.cgroup2.devices.allow: c 226:* rwm`
- NFS/SMB mount from TrueNAS for media library
- Plex Pass for hardware transcoding (optional but recommended)

**Terraform**: `terraform/lxc-plex.tf` (VM ID: 203)
**Traefik route**: `plex.woodhead.tech` -> Plex web UI (:32400)

**Notes**:
- Plex can also be accessed directly via app.plex.tv (remote access)
- Traefik route is for the local web UI
- GPU passthrough is the single most impactful optimization for transcoding

---

### Jellyfin

**Type**: LXC container (or K8s pod)
**Domain**: `jellyfin.woodhead.tech`

**Requirements**:
- Same as Plex (iGPU passthrough, NAS media mount)
- 2-4 CPU cores, 4GB RAM
- Fully open source -- no subscription needed for hardware transcoding

**Terraform**: `terraform/lxc-jellyfin.tf` (VM ID: 204)
**Traefik route**: `jellyfin.woodhead.tech` -> Jellyfin web UI (:8096)

**Notes**:
- Can run alongside Plex (same media library, different frontends)
- Better for sharing with family/friends (no Plex account required)
- DLNA support for smart TVs

---

---

## IP Address Plan

Keeping track of allocated IPs to avoid conflicts:

| IP            | Service              | Type | VM ID |
|---------------|----------------------|------|-------|
| 192.168.86.1      | Gateway (Nest WiFi)  | Router | --  |
| 192.168.86.29-31  | Proxmox nodes        | Host | --    |
| 192.168.86.20     | Traefik              | LXC  | 200   |
| 192.168.86.21     | Recipe site          | LXC  | 201   |
| 192.168.86.22     | ARR stack            | LXC  | 202   |
| 192.168.86.23     | Plex                 | LXC  | 203   |
| 192.168.86.24     | Jellyfin             | LXC  | 204   |
| 192.168.86.25     | Monitoring           | LXC  | 205   |
| 192.168.86.26     | OpenClaw             | LXC  | 206   |
| 192.168.86.27     | Authelia             | LXC  | 207   |
| 192.168.86.40     | TrueNAS              | VM   | 300   |
| 192.168.86.41     | Home Assistant       | VM   | 301   |
| 192.168.86.100    | K8s API VIP          | VIP  | --    |
| 192.168.86.101    | K8s control plane    | VM   | 400   |
| 192.168.86.111-112| K8s workers          | VM   | 410+  |
| 192.168.86.150-199| MetalLB pool         | K8s  | --    |

---

### Google OAuth / SSO

**Type**: Traefik middleware + per-service configuration
**Goal**: Single sign-on via Google accounts for all externally-exposed services.
Eliminates per-service passwords for family/friends and adds a security layer
in front of services that don't have strong built-in auth.

**Approach**: Deploy [Authelia](https://www.authelia.com/) or
[OAuth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) as a Traefik
`forwardAuth` middleware. Every request to a protected subdomain hits the auth
proxy first. If the user has a valid session cookie, the request passes through
to the backend. If not, they're redirected to Google sign-in.

**Architecture**:
```
Client -> Traefik -> forwardAuth middleware -> Authelia/OAuth2-proxy
                                                |
                                          Google OAuth2
                                          (consent screen)
                                                |
                                          Session cookie set
                                                |
Client -> Traefik -> forwardAuth (cookie valid) -> Backend service
```

**Google Cloud setup required**:
1. Create a project in Google Cloud Console
2. Configure OAuth consent screen (External, limited to specific Google accounts)
3. Create OAuth 2.0 Client ID (Web application)
4. Authorized redirect URI: `https://auth.woodhead.tech/oauth2/callback`
5. Note the Client ID and Client Secret

**Service compatibility**:

| Service       | OAuth Support                | Implementation                          |
|---------------|------------------------------|-----------------------------------------|
| Overseerr     | Built-in Google OAuth        | Configure in Settings > General         |
| Jellyfin      | OIDC plugin (SSO-Auth)       | Install plugin, configure OIDC provider |
| Home Assistant | Google sign-in integration   | Custom integration or auth proxy        |
| Traefik dash  | No built-in auth             | Protect with forwardAuth middleware     |
| Sonarr/Radarr | No OAuth support             | Protect with forwardAuth middleware     |
| Prowlarr      | No OAuth support             | Protect with forwardAuth middleware     |
| Bazarr        | No OAuth support             | Protect with forwardAuth middleware     |
| SABnzbd       | No OAuth support             | Protect with forwardAuth middleware     |
| TrueNAS       | No OAuth support             | Protect with forwardAuth middleware     |
| Plex          | Uses Plex accounts           | No change needed (own auth system)      |

**Authelia vs OAuth2-proxy**:
- **Authelia** -- More features (2FA, access control policies, LDAP), heavier,
  needs Redis + storage backend. Better if you want per-user access control
  (e.g., friends can access Overseerr but not Sonarr).
- **OAuth2-proxy** -- Simpler, stateless, just validates Google identity. Good
  enough if you only need "is this person in my allowed list?" gating.

**Recommended: Authelia** for the access control policies. Run it as a Docker
container in its own LXC or in the Traefik LXC.

**Implementation plan**:

1. **Create `auth.woodhead.tech` subdomain** -- points to Traefik (already covered by wildcard)
2. **Deploy Authelia** in the Traefik LXC (or a dedicated LXC)
   - Terraform: optionally `terraform/lxc-authelia.tf` (VM ID 205, 192.168.86.25)
   - Ansible: `ansible/playbooks/setup-authelia.yml`
   - Config: `ansible/files/authelia/configuration.yml`
3. **Configure Google OAuth2** in Authelia's identity provider settings
4. **Add Traefik forwardAuth middleware** to `ansible/files/traefik/traefik.yml`:
   ```yaml
   http:
     middlewares:
       authelia:
         forwardAuth:
           address: "http://192.168.86.20:9091/api/verify?rd=https://auth.woodhead.tech"
           trustForwardHeader: true
           authResponseHeaders:
             - Remote-User
             - Remote-Groups
   ```
5. **Apply middleware to routes** -- add `middlewares: [authelia]` to each
   service's Traefik dynamic config
6. **Configure per-service access policies** in Authelia:
   ```yaml
   access_control:
     rules:
       # Friends/family can access request portal
       - domain: requests.woodhead.tech
         policy: one_factor
         subject: "group:media-users"
       # Admin-only services
       - domain:
           - sonarr.woodhead.tech
           - radarr.woodhead.tech
           - prowlarr.woodhead.tech
         policy: two_factor
         subject: "group:admins"
   ```
7. **Allowlist Google accounts** -- only specific email addresses can sign in

**Files to create (when implementing)**:
| File | Purpose |
|------|---------|
| `terraform/lxc-authelia.tf` | LXC container (optional, can share Traefik LXC) |
| `ansible/playbooks/setup-authelia.yml` | Install + configure Authelia |
| `ansible/files/authelia/configuration.yml` | Authelia config (OAuth, policies) |
| `ansible/files/traefik/dynamic/authelia.yml` | Traefik forwardAuth middleware |

**Prerequisites**:
- Google Cloud project with OAuth2 credentials
- Traefik running with valid TLS
- Cloudflare DNS active (for `auth.woodhead.tech`)

**Security notes**:
- Authelia session secrets and Google client secret must be stored securely
  (Ansible vault or environment variables, not committed to git)
- Enable 2FA in Authelia for admin-level services
- Rate limit the auth endpoint to prevent brute force
- Regularly audit the allowed email list

---

## Implementation Priority

1. **NAS** -- storage dependency for media services
2. **ARR stack** -- needs NAS media shares
3. **Plex / Jellyfin** -- needs NAS media shares + iGPU passthrough
4. **Home Assistant** -- independent, can be done anytime
5. **Google OAuth / SSO** -- requires Traefik + Cloudflare DNS running first

## Hardware Considerations

- **GPU passthrough**: Intel iGPU (Quick Sync) is shared between Plex and Jellyfin
  via `/dev/dri`. Only one node will have the iGPU available -- pin media LXCs
  to that node.
- **Disk passthrough**: TrueNAS needs dedicated disks, not Ceph volumes. Plan
  which physical disks go to Ceph vs NAS at Proxmox install time.
- **RAM budget**: With all services running, expect ~24-32GB total usage.
  Plan node RAM accordingly.
