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

### Firewall/Router (OPNsense or pfSense)

**Type**: Proxmox VM
**Domain**: `firewall.woodhead.tech` (management UI, internal access only)
**Why VM**: A virtualized firewall/router replaces the consumer home router as the
network edge device. It handles NAT, firewall rules, VLANs, DHCP, and DNS -- giving
full control over network segmentation and traffic flow.

**OPNsense vs pfSense**:
- **OPNsense** (recommended) -- BSD-based, modern UI, frequent updates, fully open source,
  built-in WireGuard support, Unbound DNS, and a REST API for automation
- **pfSense** -- more established, larger community, but Netgate restricts CE builds
  and the UI feels dated. pfSense Plus requires a license for new features.

Both run well as Proxmox VMs. OPNsense is the better fit for a homelab that values
open source and modern tooling.

**Requirements**:
- 2 CPU cores, 2-4GB RAM, 8GB disk (minimal footprint)
- **Two network interfaces** (critical):
  - WAN: PCI passthrough of a physical NIC, or a dedicated `vmbr1` bridge connected
    to the ISP modem/ONT
  - LAN: Virtual NIC on `vmbr0` (the existing internal bridge)
- If your Proxmox node has only one physical NIC, use VLAN tagging to separate
  WAN and LAN traffic on the same wire

**Network architecture change**:
```
ISP Modem/ONT
    |
    | (WAN - public IP via DHCP from ISP)
    |
[OPNsense VM] -- handles NAT, firewall, DHCP, DNS, VLANs
    |
    | vmbr0 (LAN - 10.0.0.0/24)
    |
    +-- Traefik LXC (10.0.0.20)     -- OPNsense port-forwards 80/443 here
    +-- Recipe Site LXC (10.0.0.21)
    +-- K8s VMs (10.0.0.100+)
    +-- TrueNAS VM (10.0.0.30)
    +-- All other services
```

This replaces the consumer router entirely. The ISP modem/ONT connects directly to
the OPNsense VM's WAN interface, and OPNsense becomes the default gateway for the
entire network.

**WiFi**: Google Nest WiFi Pro mesh in **bridge mode**. Nest handles WiFi only --
OPNsense handles all routing, DHCP, and DNS. All clients land on the flat
10.0.0.0/24 network. Setup: Google Home app > WiFi > Settings > Bridge mode.

**VLANs** (deferred -- requires replacing Nest with VLAN-aware APs):
Google Nest does not support VLANs or multiple SSIDs per VLAN. VLAN segmentation
is a future upgrade requiring Ubiquiti UniFi or TP-Link Omada APs plus a
VLAN-aware managed switch. Target segmentation when ready:

| VLAN | Subnet         | Purpose                              |
|------|----------------|--------------------------------------|
| 1    | 10.0.0.0/24    | Management (Proxmox, SSH, admin UIs) |
| 10   | 10.0.10.0/24   | Trusted LAN (workstations, laptops)  |
| 20   | 10.0.20.0/24   | Servers (K8s, LXCs, NAS)             |
| 30   | 10.0.30.0/24   | IoT (Home Assistant devices, cameras) |
| 40   | 10.0.40.0/24   | Guest WiFi (isolated, internet only) |

No services require VLANs to function. The flat network works fine for all
current and planned services.

**Key features to configure**:
- **NAT / port forwarding**: 80/443 -> Traefik LXC (replaces router config)
- **DHCP server**: Static leases for all infrastructure, DHCP pool for clients
- **DNS resolver**: Unbound with local overrides (*.woodhead.tech -> internal IPs)
  - This means internal clients resolve `recipes.woodhead.tech` directly to
    10.0.0.20 without hitting Cloudflare -- faster and works during internet outages
- **WireGuard VPN**: Remote access to the homelab from anywhere
- **DDNS client**: OPNsense has built-in Cloudflare DDNS support, replacing the
  custom `cloudflare-ddns.sh` script
- **Intrusion detection**: Suricata IDS/IPS (built into OPNsense)
- **Traffic shaping**: QoS rules to prioritize Plex/Jellyfin streaming

**Terraform**: `terraform/vm-opnsense.tf` (VM ID: 100)
**Traefik route**: `firewall.woodhead.tech` -> OPNsense web UI (:443) -- internal only

**Installation**:
```bash
# Download OPNsense ISO
# https://opnsense.org/download/ (amd64, DVD image)

# Upload to Proxmox ISO storage
# Create VM with 2 NICs:
#   - net0: bridge=vmbr1 (WAN) or PCI passthrough
#   - net1: bridge=vmbr0 (LAN)
# Boot from ISO, run the installer
```

**Notes**:
- Deploy the router VM BEFORE other services if doing a full rebuild -- it becomes
  the network gateway, so nothing else gets internet without it
- If deploying alongside an existing consumer router, run OPNsense in "router on a
  stick" mode first (single NIC with VLANs) and cut over when ready
- Google Nest WiFi Pro runs in bridge mode behind OPNsense -- Nest provides WiFi
  only, OPNsense handles all routing/DHCP/DNS
- Back up the OPNsense config to TrueNAS (XML export, small file)
- OPNsense's built-in Cloudflare DDNS plugin replaces our `scripts/ddns/cloudflare-ddns.sh`
  cron job -- one less thing to maintain
- UDM (UniFi Dream Machine) available as backup hardware if OPNsense VM approach
  doesn't work out -- trades flexibility for physical independence from Proxmox

---

## IP Address Plan

Keeping track of allocated IPs to avoid conflicts:

| IP            | Service              | Type | VM ID |
|---------------|----------------------|------|-------|
| 10.0.0.1      | OPNsense (gateway)   | VM   | 100   |
| 10.0.0.10-12  | Proxmox nodes        | Host | --    |
| 10.0.0.20     | Traefik              | LXC  | 200   |
| 10.0.0.21     | Recipe site          | LXC  | 201   |
| 10.0.0.22     | ARR stack            | LXC  | 202   |
| 10.0.0.23     | Plex                 | LXC  | 203   |
| 10.0.0.24     | Jellyfin             | LXC  | 204   |
| 10.0.0.25     | Monitoring           | LXC  | 205   |
| 10.0.0.26     | OpenClaw             | LXC  | 206   |
| 10.0.0.30     | TrueNAS              | VM   | 300   |
| 10.0.0.31     | Home Assistant       | VM   | 301   |
| 10.0.0.100    | K8s API VIP          | VIP  | --    |
| 10.0.0.101    | K8s control plane    | VM   | 400   |
| 10.0.0.111-112| K8s workers          | VM   | 410+  |
| 10.0.0.150-199| MetalLB pool         | K8s  | --    |

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
| OPNsense      | No OAuth support             | Internal-only, no external exposure     |
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
   - Terraform: optionally `terraform/lxc-authelia.tf` (VM ID 205, 10.0.0.25)
   - Ansible: `ansible/playbooks/setup-authelia.yml`
   - Config: `ansible/files/authelia/configuration.yml`
3. **Configure Google OAuth2** in Authelia's identity provider settings
4. **Add Traefik forwardAuth middleware** to `ansible/files/traefik/traefik.yml`:
   ```yaml
   http:
     middlewares:
       authelia:
         forwardAuth:
           address: "http://10.0.0.20:9091/api/verify?rd=https://auth.woodhead.tech"
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

1. **OPNsense router** -- becomes the network gateway, everything depends on it
2. **NAS** -- storage dependency for media services
3. **ARR stack** -- needs NAS media shares
4. **Plex / Jellyfin** -- needs NAS media shares + iGPU passthrough
5. **Home Assistant** -- independent, can be done anytime
6. **Google OAuth / SSO** -- requires Traefik + Cloudflare DNS running first

**Note**: OPNsense can be deployed in parallel with the existing consumer router
(dual-gateway or router-on-a-stick) to avoid downtime during the transition.

## Hardware Considerations

- **GPU passthrough**: Intel iGPU (Quick Sync) is shared between Plex and Jellyfin
  via `/dev/dri`. Only one node will have the iGPU available -- pin media LXCs
  to that node.
- **Disk passthrough**: TrueNAS needs dedicated disks, not Ceph volumes. Plan
  which physical disks go to Ceph vs NAS at Proxmox install time.
- **RAM budget**: With all services running, expect ~24-32GB total usage.
  Plan node RAM accordingly.
