# Architecture

Comprehensive architecture reference for the woodhead.tech Proxmox homelab.
Covers network topology, service dependencies, traffic flow, storage, DNS/TLS,
and resource allocation.

## Table of Contents

- [Network Topology](#network-topology)
- [IP Address Allocation](#ip-address-allocation)
- [Traffic Flow: External](#traffic-flow-external)
- [Traffic Flow: Internal](#traffic-flow-internal)
- [DNS Resolution](#dns-resolution)
- [TLS Certificate Flow](#tls-certificate-flow)
- [Service Dependency Graph](#service-dependency-graph)
- [Boot Order](#boot-order)
- [Storage Architecture](#storage-architecture)
- [Resource Allocation](#resource-allocation)
- [Terraform Resource Map](#terraform-resource-map)
- [Traefik Routing Table](#traefik-routing-table)
- [ARR Stack Internal Architecture](#arr-stack-internal-architecture)
- [Kubernetes Cluster](#kubernetes-cluster)
- [VLAN Segmentation Plan](#vlan-segmentation-plan)
- [Firewall Rules](#firewall-rules)
- [Backup Strategy](#backup-strategy)

---

## Network Topology

```
                        +-----------+
                        |  Internet |
                        +-----+-----+
                              |
                        +-----+-----+
                        | ISP Modem |
                        |  (bridge) |
                        +-----+-----+
                              |
                         vmbr1 (WAN)
                              |
                   +----------+----------+
                   |   OPNsense VM 100   |
                   |     10.0.0.1        |
                   | NAT / FW / DHCP /   |
                   | DNS / VPN / IDS     |
                   +----------+----------+
                              |
                         vmbr0 (LAN)
                     10.0.0.0/24
                              |
          +-------------------+-------------------+
          |                   |                   |
    +-----+------+    +------+------+    +-------+-------+
    | Proxmox    |    | Proxmox    |    | Proxmox       |
    | Node 1     |    | Node 2     |    | Node 3 (opt.) |
    | 10.0.0.10  |    | 10.0.0.11  |    | 10.0.0.12     |
    +-----+------+    +------+------+    +-------+-------+
          |                   |                   |
          +------- Ceph Storage Mesh (3-way replication) ------+
          |
          |   +----- VMs + LXCs distributed across nodes -----+
          |   |                                                |
     +----+---+----+   +----------+   +----------+   +--------+---+
     | Traefik     |   | Recipe   |   | ARR      |   | K8s Cluster|
     | LXC 200     |   | Site     |   | Stack    |   |            |
     | 10.0.0.20   |   | LXC 201  |   | LXC 202  |   | CP: .101   |
     | :80 :443    |   | .21 :80  |   | .22      |   | W1: .111   |
     +------+------+   +----------+   +----------+   | W2: .112   |
            |                                         | VIP: .100  |
            |   +----------+   +--------------+       +------------+
            |   | TrueNAS  |   | Home         |
            |   | VM 300   |   | Assistant    |
            |   | .30      |   | VM 301       |
            |   | NFS:2049 |   | .31 :8123    |
            |   +----------+   +--------------+
            |
    +-------+-------+
    | Traefik       |
    | Routes:       |
    |  recipes.*    +---> 10.0.0.21:80
    |  sonarr.*     +---> 10.0.0.22:8989
    |  radarr.*     +---> 10.0.0.22:7878
    |  prowlarr.*   +---> 10.0.0.22:9696
    |  bazarr.*     +---> 10.0.0.22:6767
    |  requests.*   +---> 10.0.0.22:5055
    |  sabnzbd.*    +---> 10.0.0.22:8080
    |  nas.*        +---> 10.0.0.30:443
    |  home.*       +---> 10.0.0.31:8123
    |  traefik.*    +---> dashboard (local)
    |  firewall.*   +---> 10.0.0.1:443 (internal only)
    +---------------+
```

---

## IP Address Allocation

| IP              | Hostname         | Type   | VM ID | Purpose                             |
|-----------------|------------------|--------|-------|-------------------------------------|
| 10.0.0.1        | opnsense         | VM     | 100   | Gateway, firewall, DHCP, DNS        |
| 10.0.0.10       | pve1             | Host   | --    | Proxmox node 1                      |
| 10.0.0.11       | pve2             | Host   | --    | Proxmox node 2                      |
| 10.0.0.12       | pve3             | Host   | --    | Proxmox node 3 (optional)           |
| 10.0.0.20       | traefik          | LXC    | 200   | Reverse proxy, TLS termination      |
| 10.0.0.21       | recipe-site      | LXC    | 201   | Go + SQLite recipe app              |
| 10.0.0.22       | arr-stack        | LXC    | 202   | Docker: Sonarr, Radarr, etc.        |
| 10.0.0.23       | plex             | LXC    | 203   | Plex Media Server (planned)         |
| 10.0.0.24       | jellyfin         | LXC    | 204   | Jellyfin Media Server (planned)     |
| 10.0.0.30       | truenas          | VM     | 300   | NAS, ZFS, NFS/SMB shares            |
| 10.0.0.31       | homeassistant    | VM     | 301   | Home Assistant OS, smart home       |
| 10.0.0.100      | k8s-vip          | VIP    | --    | Kubernetes API endpoint             |
| 10.0.0.101      | talos-cp-0       | VM     | 400   | K8s control plane (Talos Linux)     |
| 10.0.0.111-112  | talos-worker-*   | VM     | 410+  | K8s workers (Talos Linux)           |
| 10.0.0.150-199  | metallb-pool     | K8s    | --    | MetalLB LoadBalancer IPs            |
| 10.0.0.200-254  | dhcp-pool        | DHCP   | --    | Dynamic client addresses            |

---

## Traffic Flow: External

An external request to `https://recipes.woodhead.tech`:

```
1. CLIENT                  DNS query: recipes.woodhead.tech
       |
       v
2. CLOUDFLARE DNS          Returns public IP (WAN) via A record
       |                   (Updated every 5 min by DDNS)
       v
3. ISP MODEM               Passes traffic to vmbr1 (bridge mode)
       |
       v
4. OPNSENSE WAN            Receives on public IP :443
       |                   NAT rule: :443 -> 10.0.0.20:443
       v
5. TRAEFIK (10.0.0.20)     Terminates TLS (wildcard *.woodhead.tech cert)
       |                   Matches route: Host(`recipes.woodhead.tech`)
       |                   Proxies to backend: http://10.0.0.21:80
       v
6. RECIPE SITE (10.0.0.21) Nginx :80 -> Go app :8080
       |                   Returns HTML response
       v
7. TRAEFIK                 Wraps response in TLS, sends back
       |
       v
8. OPNSENSE                Reverse NAT: 10.0.0.20 -> public IP
       |
       v
9. CLIENT                  Receives HTTPS response with valid cert
```

**Port forwarding (OPNsense WAN -> LAN):**

| WAN Port | Destination        | Protocol | Purpose             |
|----------|--------------------|----------|---------------------|
| 80       | 10.0.0.20:80       | TCP      | HTTP -> Traefik     |
| 443      | 10.0.0.20:443      | TCP      | HTTPS -> Traefik    |
| 51820    | 10.0.0.1:51820     | UDP      | WireGuard VPN (opt) |

---

## Traffic Flow: Internal

Internal clients (laptops, phones on the LAN) follow a shorter path because
OPNsense's Unbound DNS resolves `*.woodhead.tech` directly to internal IPs.

```
1. CLIENT (10.0.0.x)       DNS query: recipes.woodhead.tech
       |
       v
2. OPNSENSE UNBOUND        Local override: recipes.woodhead.tech -> 10.0.0.20
       |                   (No external DNS lookup, instant response)
       v
3. TRAEFIK (10.0.0.20)     Terminates TLS, routes to backend
       |
       v
4. RECIPE SITE (10.0.0.21) Responds directly on LAN
```

This means:
- Internal requests never leave the LAN
- Services work during internet outages (DNS is local)
- No NAT hairpin issues

---

## DNS Resolution

```
                    +-------------------+
                    |  External Client  |
                    +--------+----------+
                             |
                    +--------v----------+
                    |   Cloudflare DNS  |  Authoritative for woodhead.tech
                    |   (free tier)     |  A record: *.woodhead.tech -> public IP
                    +-------------------+  Updated by DDNS every 5 min


                    +-------------------+
                    |  Internal Client  |
                    +--------+----------+
                             |
                    +--------v----------+
                    | OPNsense Unbound  |  Local DNS resolver (10.0.0.1:53)
                    |                   |
                    |  1. Local override |  *.woodhead.tech -> 10.0.0.20
                    |     (instant)     |  nas.woodhead.tech -> 10.0.0.30
                    |                   |  home.woodhead.tech -> 10.0.0.31
                    |  2. Cache hit     |
                    |     (instant)     |
                    |                   |
                    |  3. Forward to    |  1.1.1.1, 8.8.8.8
                    |     upstream      |  (external domains only)
                    +-------------------+
```

**DNS record management:**
- **Registrar:** Squarespace (nameservers pointed to Cloudflare)
- **Authoritative DNS:** Cloudflare (free tier)
- **DDNS updates:** OPNsense built-in Cloudflare plugin (every 5 min)
- **Internal overrides:** OPNsense Unbound (*.woodhead.tech -> local IPs)

---

## TLS Certificate Flow

Traefik handles all TLS termination using Let's Encrypt certificates
obtained via Cloudflare DNS-01 challenges.

```
1. TRAEFIK detects new route requiring TLS
       |
       v
2. Requests cert from LET'S ENCRYPT
       |  Challenge type: DNS-01
       |  Resolver: "cloudflare"
       v
3. TRAEFIK creates TXT record via CLOUDFLARE API
       |  _acme-challenge.woodhead.tech = <token>
       |  Uses CF_DNS_API_TOKEN from environment
       v
4. LET'S ENCRYPT validates TXT record
       |  Queries public resolvers (1.1.1.1, 8.8.8.8)
       |  Verifies domain ownership
       v
5. Certificate issued
       |  Wildcard: *.woodhead.tech
       |  Stored: /etc/traefik/acme.json (0600)
       |  Auto-renewal: 30 days before expiry
       v
6. TRAEFIK applies cert to all matching routes
       |  Hot-reload, no restart needed
```

**Why DNS-01?**
- Supports wildcard certs (`*.woodhead.tech`) -- one cert for all subdomains
- Works before port forwarding is configured
- Works with internal-only IPs (no HTTP validation needed)
- Cloudflare free tier supports it

---

## Service Dependency Graph

```
                    +-------------------+
                    |    OPNsense       |  MUST START FIRST
                    |    (gateway)      |  Everything depends on this
                    +--------+----------+  for routing and DNS
                             |
              +--------------+--------------+
              |              |              |
    +---------v--+  +--------v---+  +------v--------+
    | TrueNAS    |  | Traefik    |  | K8s Cluster   |
    | (storage)  |  | (routing)  |  | (workloads)   |
    +-----+------+  +-----+------+  +-------+-------+
          |              |                   |
          |    +---------+---------+         |
          |    |         |         |         |
    +-----v----v-+ +----v---+ +---v---+ +---v--------+
    | ARR Stack  | | Recipe | | Home  | | K8s Pods   |
    | (media)    | | Site   | | Asst  | | (future)   |
    +------------+ +--------+ +-------+ +------------+
          |
    NFS mount
    /media
```

**Hard dependencies (service won't function without):**
- All services -> OPNsense (gateway, DNS)
- All external access -> Traefik (TLS, routing)
- ARR stack media storage -> TrueNAS (NFS at `/media`)

**Soft dependencies (service works but with reduced functionality):**
- ARR stack without TrueNAS: uses local `/media` directory (no NAS)
- Services without Traefik: accessible via direct IP:port (no TLS, no subdomain)
- K8s without MetalLB: ClusterIP services only (no external access)

---

## Boot Order

Proxmox starts VMs in this order after a host reboot. LXC containers start
in parallel after the host is ready.

| Order | Service              | VM ID | Delay  | Why                                        |
|-------|----------------------|-------|--------|--------------------------------------------|
| 1     | OPNsense             | 100   | 30s    | Network gateway -- nothing works without it |
| 2     | TrueNAS              | 300   | 30s    | NFS shares must be ready before consumers   |
| 3     | Home Assistant       | 301   | 15s    | Smart home should always be running         |
| auto  | Traefik LXC          | 200   | --     | Starts on boot, no ordering constraint      |
| auto  | Recipe Site LXC      | 201   | --     | Starts on boot                              |
| auto  | ARR Stack LXC        | 202   | --     | Starts on boot, NFS mount may retry         |
| manual| K8s Cluster          | 400+  | --     | Bootstrapped via `make bootstrap`           |

---

## Storage Architecture

```
+-- Proxmox Node -----------------------------------------+
|                                                          |
|  Physical Disks:                                         |
|  +----------+  +----------+  +----------+  +----------+ |
|  |   sda    |  |   sdb    |  |   sdc    |  |   sdd    | |
|  | Proxmox  |  | Ceph OSD |  | TrueNAS  |  | TrueNAS  | |
|  | OS +     |  |          |  | data 1   |  | data 2   | |
|  | local-lvm|  |          |  | (pass-   |  | (pass-   | |
|  |          |  |          |  |  through)|  |  through) | |
|  +----+-----+  +----+-----+  +----+-----+  +----+-----+ |
|       |              |              |              |      |
+-------+--------------+--------------+--------------+------+
        |              |              |              |
   +----v----+    +----v----+    +----v--------------v----+
   |local-lvm|    |ceph-pool|    |  TrueNAS ZFS Pool     |
   |         |    |         |    |  (mirror or RAIDZ1)    |
   | OPNsense|    | K8s CP  |    |                        |
   | TrueNAS |    | K8s     |    |  pool/media            |
   |   (OS)  |    | Workers |    |   +-- downloads/       |
   | HAOS    |    |         |    |   +-- movies/          |
   | Traefik |    |         |    |   +-- tv/              |
   | Recipe  |    |         |    |   +-- music/           |
   | ARR     |    |         |    |   +-- books/           |
   +---------+    +---------+    |                        |
                                 |  pool/backups          |
                                 |   +-- proxmox/         |
                                 |   +-- homeassistant/   |
                                 +------------------------+
```

**Storage assignments:**

| Storage      | Type       | Used By                                        |
|--------------|------------|-------------------------------------------------|
| local-lvm    | LVM (SSD)  | OPNsense OS, TrueNAS OS, HAOS, all LXC disks   |
| ceph-pool    | Ceph (3x)  | K8s control plane, K8s workers                  |
| Passthrough  | Physical   | TrueNAS ZFS data pool (via `qm set -scsi1`)    |

**NFS exports (TrueNAS -> LAN):**

| Export Path            | Mount Point  | Consumer        | Access    |
|------------------------|--------------|-----------------|-----------|
| /mnt/pool/media        | /media       | ARR Stack LXC   | Read/write|
| /mnt/pool/media        | /media       | Plex (future)   | Read-only |
| /mnt/pool/media        | /media       | Jellyfin (fut.) | Read-only |
| /mnt/pool/backups      | --           | Proxmox, HA     | Read/write|

---

## Resource Allocation

### CPU & Memory

| Service           | Cores | RAM (MB) | CPU Type | Notes                          |
|-------------------|-------|----------|----------|--------------------------------|
| OPNsense          | 2     | 4096     | host     | AES-NI for VPN, Suricata       |
| TrueNAS           | 4     | 8192     | host     | ZFS ARC cache (~1GB per TB)     |
| Home Assistant    | 2     | 2048     | host     | USB passthrough support         |
| K8s Control Plane | 2     | 4096     | x86-64   | Per node, default 1 node        |
| K8s Workers       | 4     | 8192     | x86-64   | Per node, default 2 nodes       |
| Traefik LXC       | 1     | 256      | --       | Lightweight reverse proxy       |
| Recipe Site LXC   | 1     | 512      | --       | Go binary + SQLite              |
| ARR Stack LXC     | 2     | 4096     | --       | 7 Docker containers             |

### Disk

| Service           | Size   | Storage     | Format    | Notes                       |
|-------------------|--------|-------------|-----------|-----------------------------|
| OPNsense          | 16 GB  | local-lvm   | raw       | OS only, config is tiny     |
| TrueNAS (OS)      | 16 GB  | local-lvm   | raw       | OS only                     |
| TrueNAS (data)    | varies | passthrough | ZFS       | Physical disks for pool     |
| Home Assistant    | 32 GB  | local-lvm   | qcow2     | HAOS + addons + database    |
| K8s CP            | 50 GB  | ceph-pool   | raw       | etcd + system               |
| K8s Workers       | 100 GB | ceph-pool   | raw       | Container images + volumes  |
| Traefik LXC       | 4 GB   | local-lvm   | --        | Binary + certs + configs    |
| Recipe Site LXC   | 4 GB   | local-lvm   | --        | Go binary + SQLite DB       |
| ARR Stack LXC     | 20 GB  | local-lvm   | --        | Docker + configs (media on NAS) |

### Total resource budget (all services running)

| Resource | Total       | Notes                                      |
|----------|-------------|--------------------------------------------|
| CPU      | ~20 cores   | Shared across Proxmox nodes                |
| RAM      | ~33 GB      | TrueNAS benefits from more (ZFS ARC)       |
| local-lvm| ~96 GB      | OS disks for VMs + all LXCs                |
| ceph-pool| ~250 GB raw | K8s VMs (3x replication = ~750 GB physical) |

---

## Terraform Resource Map

| Resource                                          | File                        | Type | ID  |
|---------------------------------------------------|-----------------------------|------|-----|
| `proxmox_virtual_environment_vm.opnsense`         | vm-opnsense.tf              | VM   | 100 |
| `proxmox_virtual_environment_container.traefik`   | lxc-traefik.tf              | LXC  | 200 |
| `proxmox_virtual_environment_container.recipe_site`| lxc-recipe-site.tf         | LXC  | 201 |
| `proxmox_virtual_environment_container.arr`       | lxc-arr.tf                  | LXC  | 202 |
| `proxmox_virtual_environment_vm.truenas`          | vm-truenas.tf               | VM   | 300 |
| `proxmox_virtual_environment_vm.homeassistant`    | vm-homeassistant.tf         | VM   | 301 |
| `proxmox_virtual_environment_download_file.haos_image` | vm-homeassistant.tf    | File | --  |
| `proxmox_virtual_environment_vm.controlplane[*]`  | control-plane.tf           | VM   | 400+|
| `proxmox_virtual_environment_vm.worker[*]`        | workers.tf                 | VM   | 410+|

**Provider:** [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox-virtual-environment) ~0.66.0

**Variable files:**
- `variables.tf` -- Proxmox connection, network, K8s cluster sizing
- `lxc-variables.tf` -- LXC storage, SSH key, per-service IPs/VMIDs
- `vm-opnsense-variables.tf` -- OPNsense ISO, WAN bridge, sizing
- `vm-truenas-variables.tf` -- TrueNAS ISO, sizing
- `vm-homeassistant-variables.tf` -- HAOS image URL, sizing

---

## Traefik Routing Table

All routes terminate TLS at Traefik and proxy plaintext HTTP to backends.
Certificates are wildcard (`*.woodhead.tech`) via Let's Encrypt DNS-01.

| Subdomain              | Backend              | Port  | Config File           | Status    |
|------------------------|----------------------|-------|-----------------------|-----------|
| recipes.woodhead.tech  | 10.0.0.21            | 80    | recipe-site.yml       | Active    |
| prowlarr.woodhead.tech | 10.0.0.22            | 9696  | arr-stack.yml         | Commented |
| sonarr.woodhead.tech   | 10.0.0.22            | 8989  | arr-stack.yml         | Commented |
| radarr.woodhead.tech   | 10.0.0.22            | 7878  | arr-stack.yml         | Commented |
| bazarr.woodhead.tech   | 10.0.0.22            | 6767  | arr-stack.yml         | Commented |
| requests.woodhead.tech | 10.0.0.22            | 5055  | arr-stack.yml         | Commented |
| sabnzbd.woodhead.tech  | 10.0.0.22            | 8080  | arr-stack.yml         | Commented |
| plex.woodhead.tech     | 10.0.0.23            | 32400 | media-stack.yml       | Commented |
| jellyfin.woodhead.tech | 10.0.0.24            | 8096  | media-stack.yml       | Commented |
| nas.woodhead.tech      | 10.0.0.30            | 443   | media-stack.yml       | Commented |
| home.woodhead.tech     | 10.0.0.31            | 8123  | homeassistant.yml     | Commented |
| firewall.woodhead.tech | 10.0.0.1             | 443   | opnsense.yml          | Commented |
| traefik.woodhead.tech  | localhost (dashboard) | --    | dashboard.yml         | Commented |
| *.woodhead.tech        | K8s VIP (10.0.0.100) | 80    | k8s-ingress.yml       | Commented |

Routes are in `ansible/files/traefik/dynamic/`. Uncomment as you deploy each service.
Traefik watches the directory and hot-reloads -- no restart needed.

---

## ARR Stack Internal Architecture

All ARR services run as Docker containers inside a single LXC (10.0.0.22).
They communicate via Docker's internal DNS (container names).

```
+-- ARR Stack LXC (10.0.0.22) ----------------------------------+
|                                                                 |
|  Docker Compose Network (bridge)                                |
|                                                                 |
|  +----------+  +---------+  +---------+  +---------+           |
|  | Prowlarr |  | Sonarr  |  | Radarr  |  | Bazarr  |           |
|  | :9696    |  | :8989   |  | :7878   |  | :6767   |           |
|  +----+-----+  +----+----+  +----+----+  +----+----+           |
|       |              |            |            |                 |
|       +----- Prowlarr syncs indexers to Sonarr/Radarr           |
|              Bazarr connects to Sonarr/Radarr for subs          |
|                                                                 |
|  +-----------+                                                  |
|  | Overseerr |  User-facing request portal                      |
|  | :5055     |  Connects to Sonarr + Radarr APIs                |
|  +-----------+                                                  |
|                                                                 |
|  +----------+     +----------+                                  |
|  | Gluetun  |<--->| SABnzbd  |  SABnzbd uses Gluetun's network |
|  | (VPN)    |     | :8080    |  All download traffic goes       |
|  | :8080    |     |          |  through the VPN tunnel           |
|  +----------+     +----------+                                  |
|       |                |                                        |
|       +--- VPN tunnel to provider (Mullvad, NordVPN, etc.)      |
|                                                                 |
|  Shared volume: /media (NFS from TrueNAS 10.0.0.30)            |
|  +------------------------------------------------------+      |
|  | /media/downloads/complete    <-- SABnzbd output       |      |
|  | /media/downloads/incomplete  <-- SABnzbd temp         |      |
|  | /media/movies/               <-- Radarr library       |      |
|  | /media/tv/                   <-- Sonarr library       |      |
|  | /media/music/                <-- Lidarr (future)      |      |
|  | /media/books/                <-- Readarr (future)     |      |
|  +------------------------------------------------------+      |
|                                                                 |
|  All containers run as PUID=1000, PGID=1000 (arrstack user)    |
|  LinuxServer.io images, TZ=America/Chicago                      |
+-----------------------------------------------------------------+
```

**Service configuration order:**
1. Prowlarr -- Add indexers (Usenet, torrent)
2. SABnzbd -- Configure Usenet server credentials
3. Sonarr -- Connect to Prowlarr + SABnzbd, add TV libraries
4. Radarr -- Connect to Prowlarr + SABnzbd, add movie libraries
5. Bazarr -- Connect to Sonarr + Radarr for subtitle downloads
6. Overseerr -- Connect to Sonarr + Radarr for user requests
7. Gluetun -- Configure VPN provider credentials

---

## Kubernetes Cluster

Talos Linux is an immutable, API-driven Kubernetes OS. No SSH access --
all management is through `talosctl` and `kubectl`.

```
+-- Kubernetes Cluster (talos-proxmox) ---+
|                                          |
|  API VIP: 10.0.0.100:6443               |
|                                          |
|  +-- Control Plane (10.0.0.101) ------+ |
|  |   Talos Linux v1.9.0               | |
|  |   etcd, kube-apiserver              | |
|  |   kube-scheduler, kube-controller   | |
|  |   2 cores, 4GB RAM, 50GB (Ceph)    | |
|  +------------------------------------+ |
|                                          |
|  +-- Worker 0 (10.0.0.111) -----------+ |
|  |   Talos Linux v1.9.0               | |
|  |   kubelet, kube-proxy              | |
|  |   4 cores, 8GB RAM, 100GB (Ceph)   | |
|  +------------------------------------+ |
|                                          |
|  +-- Worker 1 (10.0.0.112) -----------+ |
|  |   (same as Worker 0)               | |
|  +------------------------------------+ |
|                                          |
|  Namespaces: ingress-system, apps,       |
|              monitoring, metallb-system   |
|                                          |
|  MetalLB: L2 mode                        |
|  IP Pool: 10.0.0.150 - 10.0.0.199       |
|                                          |
+------------------------------------------+
```

**Scaling:** Update `terraform.tfvars` (counts + IPs), then `make apply && make bootstrap`.

---

## VLAN Segmentation Plan

Currently all services run on a flat 10.0.0.0/24 network. Recommended
future segmentation via OPNsense VLAN support:

| VLAN | Subnet         | Purpose           | Example Devices                    |
|------|----------------|-------------------|------------------------------------|
| 1    | 10.0.0.0/24    | Management        | Proxmox nodes, SSH, admin UIs      |
| 10   | 10.0.10.0/24   | Trusted LAN       | Workstations, laptops              |
| 20   | 10.0.20.0/24   | Servers           | K8s, LXCs, NAS, Traefik           |
| 30   | 10.0.30.0/24   | IoT               | Zigbee, Z-Wave, cameras, sensors   |
| 40   | 10.0.40.0/24   | Guest WiFi        | Visitors (internet only)           |

**Inter-VLAN firewall rules:**

```
Trusted (10) ---> Servers (20)     ALLOW   (access services)
Trusted (10) ---> IoT (30)         ALLOW   (manage devices)
IoT (30) -------> HA (10.0.0.31)   ALLOW   (smart home control)
IoT (30) -------> Servers (20)     DENY    (isolate compromised devices)
IoT (30) -------> Trusted (10)     DENY    (protect workstations)
Guest (40) -----> Internet         ALLOW   (internet only)
Guest (40) -----> ALL internal     DENY    (full isolation)
```

Requires: VLAN-aware managed switch + OPNsense VLAN interface config.

---

## Firewall Rules

### WAN (OPNsense external interface)

| Rule     | Protocol | Source | Dest Port | Action  | Notes                  |
|----------|----------|--------|-----------|---------|------------------------|
| Default  | *        | *      | *         | DENY    | Block all inbound      |
| HTTP     | TCP      | *      | 80        | NAT FWD | -> 10.0.0.20:80        |
| HTTPS    | TCP      | *      | 443       | NAT FWD | -> 10.0.0.20:443       |
| WireGuard| UDP      | *      | 51820     | NAT FWD | -> 10.0.0.1:51820 (opt)|

### LAN (default allow, restrict as VLANs are added)

| Rule     | Source        | Dest         | Action | Notes                    |
|----------|---------------|--------------|--------|--------------------------|
| Default  | 10.0.0.0/24   | *            | ALLOW  | Trust LAN (pre-VLAN)     |
| Anti-spoof| != LAN subnet| LAN          | DENY   | Block spoofed sources    |

---

## Backup Strategy

| What                | Where                        | Method                          | Frequency  |
|---------------------|------------------------------|---------------------------------|------------|
| Proxmox VMs         | TrueNAS /pool/backups        | Proxmox backup job -> NFS       | Weekly     |
| OPNsense config     | TrueNAS /pool/backups        | XML export (via web UI)         | After changes |
| Home Assistant      | TrueNAS /pool/backups/ha     | Built-in snapshots -> NFS       | Daily      |
| ARR stack configs   | TrueNAS /pool/backups        | Backup /opt/arr/ directory      | Weekly     |
| Traefik certs       | Included in LXC backup       | acme.json auto-renews if lost   | --         |
| K8s state           | etcd (on control plane disk)  | Velero (future)                | --         |
| TrueNAS config      | TrueNAS self                 | Config export (JSON)            | After changes |
| Recipe site DB      | Included in LXC backup       | SQLite file in /opt/            | Weekly     |

**Offsite (recommended future):** Replicate TrueNAS backups to cloud storage
or rotate USB drives.

---

## Automation Toolchain

```
+-- Local Machine (macOS) ----+
|                              |
|  Makefile (orchestration)    |
|       |                      |
|       +-- Terraform          |  Provisions VMs + LXCs on Proxmox
|       |   (bpg/proxmox)     |  State: terraform/terraform.tfstate
|       |                      |
|       +-- Ansible            |  Configures services inside VMs/LXCs
|       |   (playbooks)        |  Inventory: ansible/inventory/hosts.yml
|       |                      |
|       +-- talosctl           |  Manages Talos Linux (no SSH)
|       |                      |  Config: talos/_out/talosconfig
|       |                      |
|       +-- kubectl            |  Manages K8s workloads
|       |                      |  Config: talos/_out/kubeconfig
|       |                      |
|       +-- Scripts            |  Bootstrap, destroy, DDNS, K8s base
|                              |
+------------------------------+
```
