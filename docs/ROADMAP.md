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

### WireGuard VPN

**Type**: LXC container (lightweight tunnel endpoint)
**Domain**: `vpn.woodhead.tech` (for documentation; VPN uses UDP, not HTTP)
**Goal**: Secure remote access to the entire homelab LAN from anywhere.
Connect from laptop/phone while away and access all services as if on the
local network -- no port forwarding needed beyond the VPN port.

**Why WireGuard**: Modern, fast, minimal attack surface. Single UDP port,
kernel-level performance, simple config. Replaces clunky OpenVPN setups.

**Architecture**:
```
Phone/Laptop (remote)
    |
    | WireGuard tunnel (UDP 51820)
    |
    v
ISP Modem -> Google Nest (port forward UDP 51820)
    |
    v
WireGuard LXC (192.168.86.39)
    |
    | IP forwarding + masquerade
    |
    v
192.168.86.0/24 (full LAN access)
```

**Requirements**:
- 1 CPU core, 256 MB RAM, 2 GB disk (extremely lightweight)
- Port forward: UDP 51820 on Google Nest -> WireGuard LXC
- Static public IP or DDNS (already running for Cloudflare)
- IP forwarding enabled in the LXC (`net.ipv4.ip_forward=1`)

**Approach options**:
1. **Dedicated LXC** (VM ID 208, IP 192.168.86.39) -- cleanest isolation,
   own Terraform + Ansible like other services
2. **Run on Proxmox host directly** -- simplest, no LXC overhead, but
   mixes concerns with the hypervisor
3. **Run in existing LXC** (e.g., Traefik) -- fewer containers, but
   couples unrelated services

**Recommended: Dedicated LXC**. Follows the existing pattern and keeps the
VPN endpoint isolated. If the VPN LXC is compromised, other services are
unaffected (assuming firewall rules are added later).

**VPN subnet**: `10.10.0.0/24` (separate from LAN)
- `10.10.0.1` -- WireGuard server (LXC)
- `10.10.0.2` -- Brandon's laptop
- `10.10.0.3` -- Brandon's phone
- `10.10.0.4+` -- additional clients

**Implementation plan**:
1. `terraform/lxc-wireguard.tf` -- LXC container (VM ID 208, 192.168.86.39)
2. `ansible/playbooks/setup-wireguard.yml` -- Install WireGuard, generate
   server + client keys, configure interface, enable IP forwarding
3. Generate client configs (QR codes for phone, .conf files for laptop)
4. Port forward UDP 51820 on Google Nest -> 192.168.86.39
5. Traefik route not needed (WireGuard is UDP, not HTTP)

**Client setup**:
- macOS/Windows/Linux: official WireGuard app, import `.conf` file
- iOS/Android: WireGuard app, scan QR code from server

**DNS inside tunnel**: Clients use the LAN DNS (192.168.86.1) so
`*.woodhead.tech` resolves via hairpin NAT or split DNS. Alternatively,
set DNS to a Pi-hole/AdGuard instance in the future.

**Security notes**:
- Private keys generated on the server, never transmitted in plaintext
- Client configs contain pre-shared keys for post-quantum resistance
- Ansible playbook stores keys in `/etc/wireguard/` (mode 0600)
- Keys are injected via `--extra-vars` or generated at deploy time
- Consider AllowedIPs restrictions per client (e.g., phone only gets
  media services, not admin tools)

**Files**:
| File | Purpose |
|------|---------|
| `terraform/lxc-wireguard.tf` | LXC container (deployed) |
| `terraform/lxc-wireguard-variables.tf` | VM ID, IP variables |
| `ansible/playbooks/setup-wireguard.yml` | Install + configure WireGuard |
| `ansible/files/wireguard/wg0.conf.j2` | Server config template |
| `ansible/files/wireguard/client.conf.j2` | Client config template |

---

### Docusaurus Documentation Site

**Type**: Docker container on existing LXC or K8s pod
**Domain**: `docs.woodhead.tech`
**Goal**: Centralized documentation site for the homelab -- runbooks, architecture
diagrams, user guides, and operational procedures. Replaces the scattered markdown
files in the repo with a searchable, versioned, browsable site.

**Why Docusaurus**: React-based, Markdown-driven, built-in search, versioning,
and sidebar navigation. Deploys as a static site (nginx or K8s). Already familiar
from syssec-docs at work.

**Content to migrate**:
- `docs/ARCHITECTURE.md` -- network topology, resource allocation
- `docs/RUNBOOK.md` -- deployment walkthroughs per service
- `docs/PATCHING.md` -- update strategies
- `docs/ROADMAP.md` -- planned services
- Per-service user guides (ARR stack setup, Plex libraries, VPN client config)
- Operational playbooks (Ceph recovery, node failure, certificate rotation)

**Requirements**:
- Node.js build step (Docusaurus generates static HTML)
- Minimal runtime: nginx serving static files, or Kubernetes Deployment
- CI/CD: rebuild on push to docs branch (GitHub Actions or manual `make docs`)
- ~256MB RAM, 1 CPU core at runtime (static files)

**Deployment options**:
1. **K8s pod** (preferred) -- Dockerfile builds the site, Deployment serves it,
   Traefik IngressRoute routes `docs.woodhead.tech`
2. **Existing LXC** -- build locally, rsync static output to an nginx container
3. **Dedicated LXC** -- overkill for a static site

**Implementation plan**:
1. `docs-site/` directory in this repo (Docusaurus project)
2. Dockerfile: multi-stage build (node -> nginx)
3. K8s manifests or Docker Compose for deployment
4. Traefik route: `docs.woodhead.tech`
5. Migrate existing markdown content into Docusaurus structure
6. Makefile target: `make docs`

---

### Resume / Portfolio Site

**Type**: Static site (K8s pod or LXC container)
**Domain**: `resume.woodhead.tech`
**Goal**: Personal resume and portfolio site showcasing projects and experience.

**Options**:
1. **Static HTML/CSS** -- simple, fast, no framework overhead
2. **Hugo/Jekyll** -- Markdown-driven, theme ecosystem, easy to update
3. **React/Next.js** -- more interactive, heavier build

**Requirements**:
- Minimal: static file serving (nginx)
- ~256MB RAM, 1 CPU core
- Traefik route: `resume.woodhead.tech`

**Implementation plan**:
1. `resume-site/` directory in this repo (or separate repo)
2. Choose framework (Hugo recommended for simplicity + themes)
3. Dockerfile: multi-stage build -> nginx
4. K8s manifests or Docker Compose
5. Traefik route: `resume.woodhead.tech`
6. Makefile target: `make resume`

---

## IP Address Plan

Keeping track of allocated IPs to avoid conflicts:

| IP            | Service              | Type | VM ID |
|---------------|----------------------|------|-------|
| 192.168.86.1      | Gateway (Nest WiFi)  | Router | --  |
| 192.168.86.29-31  | Proxmox nodes (thinkcentre1–3) | Host | --    |
| 192.168.86.130    | tower1 (Proxmox node)  | Host | --    |
| 192.168.86.147    | zotac (Proxmox node)   | Host | --    |
| 192.168.86.20     | Traefik              | LXC  | 200   |
| 192.168.86.21     | Recipe site          | LXC  | 201   |
| 192.168.86.22     | ARR stack            | LXC  | 202   |
| 192.168.86.23     | Plex                 | LXC  | 203   |
| 192.168.86.24     | Jellyfin             | LXC  | 204   |
| 192.168.86.25     | Monitoring           | LXC  | 205   |
| 192.168.86.26     | OpenClaw             | LXC  | 206   |
| 192.168.86.28     | Authentik            | LXC  | 207   |
| 192.168.86.32     | SDR Scanner          | LXC  | 210   |
| 192.168.86.39     | WireGuard VPN        | LXC  | 208   |
| 192.168.86.27     | Libby Alert          | LXC  | 209   |
| 192.168.86.40     | TrueNAS              | VM   | 300   |
| 192.168.86.41     | Home Assistant       | VM   | 301   |
| 192.168.86.131    | Piboard dashboard    | Pi   | --    |
| 192.168.86.138    | Klipper Ender 3      | Pi   | --    |
| 192.168.86.136    | Klipper Ender 5 Pro  | Pi   | --    |
| 192.168.86.100    | K8s API VIP          | VIP  | --    |
| 192.168.86.101    | K8s control plane    | VM   | 400   |
| 192.168.86.111-112| K8s workers          | VM   | 410+  |
| 192.168.86.150-199| MetalLB pool         | K8s  | --    |

---

### Authentik SSO

**Status**: DONE

**Type**: LXC 207 | `192.168.86.28` | Docker Compose
**Domain**: `auth.woodhead.tech`

Authentik replaced the originally planned Authelia. It provides domain-level forward auth
for all `*.woodhead.tech` subdomains via a single Traefik `forwardAuth` middleware (`authentik@file`).

**Current setup**:
- Single `woodhead-forward-auth` proxy provider in `forward_domain` mode covering `woodhead.tech`
- `admins` group — full access to all services (bwoodwar@gmail.com, lips42@gmail.com)
- Google OAuth source configured for login
- Outpost embedded in Authentik server container

**Files**:
| File | Purpose |
|------|---------|
| `terraform/lxc-authentik.tf` | LXC container (VM ID 207) |
| `ansible/playbooks/setup-authentik.yml` | Install + configure Authentik |
| `ansible/files/traefik/dynamic/authentik.yml` | Traefik forwardAuth middleware |

**Service protection** — add `middlewares: [authentik@file]` to any Traefik route to protect it:
| Service | Protected |
|---------|-----------|
| Sonarr, Radarr, Prowlarr, Bazarr | Yes |
| SABnzbd, Seerr | Yes |
| TrueNAS (`nas.woodhead.tech`) | Yes |
| SDR Scanner (`scanner.woodhead.tech`) | Yes |
| Grafana, docs, resume | Yes |
| Plex | No (uses Plex accounts) |

---

---

### Proxmox Backups via TrueNAS NFS

**Blocked on**: TrueNAS setup (NFS share must exist first)

**Plan**:
1. On TrueNAS: create a dataset (e.g., `tank/proxmox-backups`) and export it as NFS
   - Restrict access to the Proxmox subnet (`192.168.86.0/24`)
   - Use NFS v4, async writes for performance
2. On all Proxmox nodes: add NFS storage endpoint via `pvesm add nfs`
   - Storage ID: `truenas-backups`
   - Content type: `backup`
   - Mount point: `/mnt/pve/truenas-backups`
3. Create a cluster-wide backup job via Proxmox UI or `pvesh`:
   - Schedule: nightly (e.g., 02:00)
   - Mode: snapshot (zero downtime for running VMs)
   - Compression: zstd
   - Retention: 7 daily, 4 weekly
   - Target: `truenas-backups` storage
   - Scope: all VMs and LXCs across all nodes (thinkcentre1–3, tower1)

**Nodes to include**: thinkcentre1, thinkcentre2, thinkcentre3, tower1, zotac

**VMs/LXCs to back up** (currently none have backup jobs):
| ID  | Name                   | Node          |
|-----|------------------------|---------------|
| 200 | traefik                | thinkcentre1  |
| 201 | recipe-site            | thinkcentre1  |
| 202 | arr-stack              | thinkcentre2  |
| 203 | plex                   | thinkcentre2  |
| 204 | jellyfin               | thinkcentre3  |
| 205 | monitoring             | thinkcentre2  |
| 206 | openclaw               | thinkcentre3  |
| 207 | authentik              | thinkcentre1  |
| 208 | wireguard              | thinkcentre1  |
| 209 | libby-alert            | thinkcentre1  |
| 300 | truenas                | tower1        |
| 301 | homeassistant          | thinkcentre1  |
| 400 | talos-proxmox-cp-0     | tower1        |
| 410 | talos-proxmox-worker-0 | tower1        |
| 411 | talos-proxmox-worker-1 | thinkcentre3  |

---

## Implementation Priority

1. **NAS** -- DONE (TrueNAS Scale 24.04, ZFS pool `tank` on 2TB Ceph RBD, NFS shares for media/backups/isos)
2. **Proxmox Backups** -- DONE (truenas-backups NFS storage added, nightly 02:00 snapshot job, 7-day retention)
3. **ARR stack** -- DONE (LXC with Docker Compose, NFS via Proxmox host bind-mount; gluetun WireGuard VPN killswitch for SABnzbd via PrivadoVPN)
4. **Plex / Jellyfin** -- DONE (LXCs with iGPU passthrough, NFS via Proxmox host bind-mount)
5. **Home Assistant** -- DONE (HAOS VM at 192.168.86.41, trusted_proxies configured, home.woodhead.tech via Traefik)
6. **Authentik SSO** -- DONE (deployed at auth.woodhead.tech; admins + media-users groups; access policy restricts admin services; Google OAuth source configured)
7. **WireGuard VPN** -- DONE (LXC, UDP 51820, split tunnel to LAN)
8. **Resource Balancing** -- DONE (tower1 added, Talos VMs redistributed across nodes)
9. **Piboard Dashboard** -- DONE (Raspberry Pi 3B + Waveshare 5" HDMI, Go + SSE + Prometheus)
10. **Klipper 3D Printing** -- IN PROGRESS (Ender 5 Pro on Pi 3B with MainsailOS, Ender 3 planned)
11. **Talos K8s Cluster** -- DONE (3-node cluster bootstrapped: CP at 192.168.86.143, workers at .144/.145; Flannel CNI; namespaces: ingress-system, apps, monitoring; configs in talos/_out/)
12. **SDR Scanner** -- DONE (LXC 210 on thinkcentre2, Trunk Recorder + rdio-scanner, RTL-SDR V4 USB passthrough, SNO911 P25 Phase II, scanner.woodhead.tech)
13. **Dexcom Glucose Monitoring** -- IN PROGRESS (Python exporter -> Prometheus -> Grafana dashboard; Alertmanager routes to Twilio SMS + Home Assistant Alexa; needs Dexcom Share credentials + Twilio account)
14. **Docusaurus Docs Site** -- DONE (docs.woodhead.tech; deployed on monitoring LXC; Traefik route + Authentik SSO)
15. **Resume Site** -- DONE (resume.woodhead.tech; Hugo static site deployed on monitoring LXC)

## Hardware Considerations

- **GPU passthrough**: Intel iGPU (Quick Sync) is shared between Plex and Jellyfin
  via `/dev/dri`. Only one node will have the iGPU available -- pin media LXCs
  to that node.
- **Disk passthrough**: TrueNAS needs dedicated disks, not Ceph volumes. Plan
  which physical disks go to Ceph vs NAS at Proxmox install time.
- **RAM budget**: With all services running, expect ~24-32GB total usage.
  Plan node RAM accordingly.
