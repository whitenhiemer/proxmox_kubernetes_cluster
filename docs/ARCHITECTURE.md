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
                        +-----+-----+
                              |
                   +----------+----------+
                   | Google Nest WiFi    |
                   | Pro (router/mesh)   |
                   |     10.0.0.1        |
                   | NAT / DHCP / DNS /  |
                   | WiFi                |
                   +----------+----------+
                              |
                         10.0.0.0/24 (flat LAN)
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
            |   +----------+   +----------+           +------------+
            |   | Plex     |   | Jellyfin |
            |   | LXC 203  |   | LXC 204  |
            |   | .23      |   | .24      |
            |   | :32400   |   | :8096    |
            |   | iGPU     |   | iGPU     |
            |   +----------+   +----------+
            |
            |   +----------+   +--------------+
            |   | TrueNAS  |   | Home         |
            |   | VM 300   |   | Assistant    |
            |   | .30      |   | VM 301       |
            |   | NFS:2049 |   | .31 :8123    |
            |   +----------+   +--------------+
            |
            |   +----------+
            |   | OpenClaw |
            |   | LXC 206  |
            |   | .26      |
            |   | :18789   |
            |   +----------+
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
    |  claw.*       +---> 10.0.0.26:18789
    |  grafana.*    +---> 10.0.0.25:3000
    |  prometheus.* +---> 10.0.0.25:9090
    |  traefik.*    +---> dashboard (local)
    +---------------+
```

---

## IP Address Allocation

| IP              | Hostname         | Type   | VM ID | Purpose                             |
|-----------------|------------------|--------|-------|-------------------------------------|
| 10.0.0.1        | nest-gateway     | Router | --    | Google Nest WiFi Pro (NAT, DHCP, DNS)|
| 10.0.0.10       | pve1             | Host   | --    | Proxmox node 1                      |
| 10.0.0.11       | pve2             | Host   | --    | Proxmox node 2                      |
| 10.0.0.12       | pve3             | Host   | --    | Proxmox node 3 (optional)           |
| 10.0.0.20       | traefik          | LXC    | 200   | Reverse proxy, TLS termination      |
| 10.0.0.21       | recipe-site      | LXC    | 201   | Go + SQLite recipe app              |
| 10.0.0.22       | arr-stack        | LXC    | 202   | Docker: Sonarr, Radarr, etc.        |
| 10.0.0.23       | plex             | LXC    | 203   | Plex Media Server + iGPU            |
| 10.0.0.24       | jellyfin         | LXC    | 204   | Jellyfin Media Server + iGPU        |
| 10.0.0.25       | monitoring       | LXC    | 205   | Prometheus, Grafana, Alertmanager   |
| 10.0.0.26       | openclaw         | LXC    | 206   | OpenClaw AI agent framework         |
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
3. ISP MODEM               Passes traffic to Google Nest
       |
       v
4. GOOGLE NEST             Receives on public IP :443
       |                   Port forward: :443 -> 10.0.0.20:443
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
8. GOOGLE NEST             Reverse NAT: 10.0.0.20 -> public IP
       |
       v
9. CLIENT                  Receives HTTPS response with valid cert
```

**Port forwarding (Google Nest -> LAN):**

Configure via Google Home app > WiFi > Settings > Advanced Networking > Port Management.

| WAN Port | Destination        | Protocol | Purpose             |
|----------|--------------------|----------|---------------------|
| 80       | 10.0.0.20:80       | TCP      | HTTP -> Traefik     |
| 443      | 10.0.0.20:443      | TCP      | HTTPS -> Traefik    |

---

## Traffic Flow: Internal

Internal clients (laptops, phones on the LAN) resolve `*.woodhead.tech` via
Cloudflare DNS (upstream from Google Nest). The Nest supports hairpin NAT,
so traffic loops back to Traefik without leaving the network.

```
1. CLIENT (10.0.0.x)       DNS query: recipes.woodhead.tech
       |
       v
2. GOOGLE NEST DNS          Forwards to upstream (8.8.8.8 / 1.1.1.1)
       |                   Returns public IP from Cloudflare
       v
3. CLIENT                  Connects to public IP :443
       |
       v
4. GOOGLE NEST             Hairpin NAT: public IP -> 10.0.0.20:443
       |
       v
5. TRAEFIK (10.0.0.20)     Terminates TLS, routes to backend
       |
       v
6. RECIPE SITE (10.0.0.21) Responds directly on LAN
```

Note: Unlike a dedicated firewall with local DNS overrides, internal
requests still depend on external DNS resolution. Services are unreachable
during internet outages unless clients have static hosts file entries.

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
                    | Google Nest DNS   |  Forwards to upstream resolvers
                    |   (10.0.0.1:53)  |
                    |                   |
                    |  1. Cache hit     |
                    |     (instant)     |
                    |                   |
                    |  2. Forward to    |  Google DNS (8.8.8.8) or
                    |     upstream      |  user-configured upstream
                    |                   |
                    |  3. Returns       |  Public IP from Cloudflare
                    |     public IP     |  Hairpin NAT resolves locally
                    +-------------------+
```

**DNS record management:**
- **Registrar:** Squarespace (nameservers pointed to Cloudflare)
- **Authoritative DNS:** Cloudflare (free tier)
- **DDNS updates:** Cron script on Proxmox node (every 5 min)
- **Internal resolution:** Google Nest forwards to upstream DNS; hairpin NAT loops traffic back to Traefik

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
    Google Nest WiFi Pro (10.0.0.1)
    Router, NAT, DHCP, DNS, WiFi
    (physical device, not managed by Proxmox)
              |
              +-- 10.0.0.0/24 (flat LAN)
              |
    +---------+---------+--------------+
    |         |         |              |
    v         v         v              v
+--------+ +--------+ +----------+ +--------+
|TrueNAS | |Traefik | |K8s       | |Home    |
|(storage)| |(routing)| |Cluster  | |Asst    |
+---+----+ +---+----+ +----+-----+ +--------+
    |          |            |
    |   +------+------+    |
    |   |      |      |    |
    v   v      v      v    v
+-------+-+ +------+ +----------+
|ARR Stack| |Recipe| |K8s Pods  |
|(media)  | |Site  | |(future)  |
+----+----+ +------+ +----------+
     |
+----v-----------+
| Monitoring     |  Scrapes all services via
| (Prometheus)   |  PVE Exporter, Blackbox,
| (observes all) |  Traefik metrics, K8s exporters
+----------------+
     |
NFS mount (/media, read-write)
     |
+----v-------+ +------------+
| Plex       | | Jellyfin   |
| (media)    | | (media)    |
+------------+ +------------+
     |              |
NFS mount (/media, read-only)
```

**Hard dependencies (service won't function without):**
- All services -> Google Nest gateway (routing, DHCP, DNS)
- All external access -> Traefik (TLS, routing)
- ARR stack media storage -> TrueNAS (NFS at `/media`)
- Plex/Jellyfin media library -> TrueNAS (NFS at `/media`, read-only)
- Plex/Jellyfin transcoding -> iGPU (`/dev/dri` passthrough from Proxmox host)

**Soft dependencies (service works but with reduced functionality):**
- ARR stack without TrueNAS: uses local `/media` directory (no NAS)
- Plex/Jellyfin without TrueNAS: no media to serve
- Plex/Jellyfin without iGPU: falls back to software transcoding (CPU-heavy)
- Services without Traefik: accessible via direct IP:port (no TLS, no subdomain)
- K8s without MetalLB: ClusterIP services only (no external access)
- Monitoring without PVE token: Proxmox metrics unavailable (all other scrapes still work)
- Monitoring without K8s manifests: K8s metrics unavailable (deploy kube-state-metrics later)

---

## Boot Order

Proxmox starts VMs in this order after a host reboot. LXC containers start
in parallel after the host is ready.

| Order | Service              | VM ID | Delay  | Why                                        |
|-------|----------------------|-------|--------|--------------------------------------------|
| 1     | TrueNAS              | 300   | 30s    | NFS shares must be ready before consumers   |
| 2     | Home Assistant       | 301   | 15s    | Smart home should always be running         |
| auto  | Traefik LXC          | 200   | --     | Starts on boot, no ordering constraint      |
| auto  | Recipe Site LXC      | 201   | --     | Starts on boot                              |
| auto  | ARR Stack LXC        | 202   | --     | Starts on boot, NFS mount may retry         |
| auto  | Plex LXC             | 203   | --     | Starts on boot, iGPU node pinned            |
| auto  | Jellyfin LXC         | 204   | --     | Starts on boot, iGPU node pinned            |
| auto  | Monitoring LXC       | 205   | --     | Starts on boot, scrapes all services        |
| auto  | OpenClaw LXC         | 206   | --     | Starts on boot, AI agent framework          |
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
   | TrueNAS |    | K8s CP  |    |                        |
   |  (OS)   |    | K8s     |    |  pool/media            |
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
| local-lvm    | LVM (SSD)  | TrueNAS OS, HAOS, all LXC disks                 |
| ceph-pool    | Ceph (3x)  | K8s control plane, K8s workers                  |
| Passthrough  | Physical   | TrueNAS ZFS data pool (via `qm set -scsi1`)    |

**NFS exports (TrueNAS -> LAN):**

| Export Path            | Mount Point  | Consumer        | Access    |
|------------------------|--------------|-----------------|-----------|
| /mnt/pool/media        | /media       | ARR Stack LXC   | Read/write|
| /mnt/pool/media        | /media       | Plex LXC        | Read-only |
| /mnt/pool/media        | /media       | Jellyfin LXC    | Read-only |
| /mnt/pool/backups      | --           | Proxmox, HA     | Read/write|

---

## Resource Allocation

### CPU & Memory

| Service           | Cores | RAM (MB) | CPU Type | Notes                          |
|-------------------|-------|----------|----------|--------------------------------|
| TrueNAS           | 4     | 8192     | host     | ZFS ARC cache (~1GB per TB)     |
| Home Assistant    | 2     | 2048     | host     | USB passthrough support         |
| K8s Control Plane | 2     | 4096     | x86-64   | Per node, default 1 node        |
| K8s Workers       | 4     | 8192     | x86-64   | Per node, default 2 nodes       |
| Traefik LXC       | 1     | 256      | --       | Lightweight reverse proxy       |
| Recipe Site LXC   | 1     | 512      | --       | Go binary + SQLite              |
| Plex LXC          | 2     | 2048     | --       | iGPU passthrough for Quick Sync |
| Jellyfin LXC      | 2     | 2048     | --       | iGPU passthrough for VAAPI      |
| Monitoring LXC    | 2     | 2048     | --       | Prometheus, Grafana, exporters  |
| OpenClaw LXC      | 2     | 2048     | --       | AI agent gateway + CLI          |
| ARR Stack LXC     | 2     | 4096     | --       | 7 Docker containers             |

### Disk

| Service           | Size   | Storage     | Format    | Notes                       |
|-------------------|--------|-------------|-----------|-----------------------------|
| TrueNAS (OS)      | 16 GB  | local-lvm   | raw       | OS only                     |
| TrueNAS (data)    | varies | passthrough | ZFS       | Physical disks for pool     |
| Home Assistant    | 32 GB  | local-lvm   | qcow2     | HAOS + addons + database    |
| K8s CP            | 50 GB  | ceph-pool   | raw       | etcd + system               |
| K8s Workers       | 100 GB | ceph-pool   | raw       | Container images + volumes  |
| Traefik LXC       | 4 GB   | local-lvm   | --        | Binary + certs + configs    |
| Recipe Site LXC   | 4 GB   | local-lvm   | --        | Go binary + SQLite DB       |
| Plex LXC          | 8 GB   | local-lvm   | --        | Plex binary + DB (media on NAS) |
| Jellyfin LXC      | 8 GB   | local-lvm   | --        | Jellyfin binary + DB (media on NAS) |
| Monitoring LXC    | 20 GB  | local-lvm   | --        | Prometheus TSDB (30-day retention)  |
| OpenClaw LXC      | 20 GB  | local-lvm   | --        | Source build + Docker images + workspace |
| ARR Stack LXC     | 20 GB  | local-lvm   | --        | Docker + configs (media on NAS) |

### Total resource budget (all services running)

| Resource | Total       | Notes                                      |
|----------|-------------|--------------------------------------------|
| CPU      | ~26 cores   | Shared across Proxmox nodes                |
| RAM      | ~37 GB      | TrueNAS benefits from more (ZFS ARC)       |
| local-lvm| ~136 GB     | OS disks for VMs + all LXCs                |
| ceph-pool| ~250 GB raw | K8s VMs (3x replication = ~750 GB physical) |

---

## Terraform Resource Map

| Resource                                          | File                        | Type | ID  |
|---------------------------------------------------|-----------------------------|------|-----|
| `proxmox_virtual_environment_container.traefik`   | lxc-traefik.tf              | LXC  | 200 |
| `proxmox_virtual_environment_container.recipe_site`| lxc-recipe-site.tf         | LXC  | 201 |
| `proxmox_virtual_environment_container.arr`       | lxc-arr.tf                  | LXC  | 202 |
| `proxmox_virtual_environment_container.plex`      | lxc-plex.tf                 | LXC  | 203 |
| `proxmox_virtual_environment_container.jellyfin`  | lxc-jellyfin.tf             | LXC  | 204 |
| `proxmox_virtual_environment_container.monitoring`| lxc-monitoring.tf           | LXC  | 205 |
| `proxmox_virtual_environment_container.openclaw`  | lxc-openclaw.tf             | LXC  | 206 |
| `proxmox_virtual_environment_vm.truenas`          | vm-truenas.tf               | VM   | 300 |
| `proxmox_virtual_environment_vm.homeassistant`    | vm-homeassistant.tf         | VM   | 301 |
| `proxmox_virtual_environment_download_file.haos_image` | vm-homeassistant.tf    | File | --  |
| `proxmox_virtual_environment_vm.controlplane[*]`  | control-plane.tf           | VM   | 400+|
| `proxmox_virtual_environment_vm.worker[*]`        | workers.tf                 | VM   | 410+|

**Provider:** [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox-virtual-environment) ~0.66.0

**Variable files:**
- `variables.tf` -- Proxmox connection, network, K8s cluster sizing
- `lxc-variables.tf` -- LXC storage, SSH key, per-service IPs/VMIDs
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
| grafana.woodhead.tech  | 10.0.0.25            | 3000  | monitoring.yml        | Commented |
| prometheus.woodhead.tech| 10.0.0.25           | 9090  | monitoring.yml        | Commented |
| alertmanager.woodhead.tech| 10.0.0.25         | 9093  | monitoring.yml        | Commented |
| claw.woodhead.tech     | 10.0.0.26            | 18789 | openclaw.yml          | Commented |
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

## WiFi / Network Architecture

Google Nest WiFi Pro mesh serves as the network router and WiFi access point.
It handles NAT, DHCP, DNS forwarding, and WiFi for all clients.

```
ISP Modem/ONT
    |
    +-- Google Nest WiFi Pro (10.0.0.1)
            |  Router mode (default)
            |  NAT, DHCP, DNS forwarding, WiFi
            |
            +-- Primary unit (wired to ISP modem + switch)
            +-- Satellite(s) (wireless mesh backhaul)
            |
            +-- [Switch] -- Proxmox nodes, wired devices
            |
            WiFi + wired clients on 10.0.0.0/24
```

**Port forwarding**: Google Home app > WiFi > Settings > Advanced Networking >
Port Management. Forward 80/443 to Traefik LXC (10.0.0.20).

**DDNS**: Cloudflare DDNS script runs on a Proxmox node via cron (every 5 min).

**Limitation**: Google Nest does not support VLANs or multiple SSIDs per VLAN.
All clients land on the same flat 10.0.0.0/24 network. This is fine
for current use -- no services require VLAN segmentation to function.

---

## VLAN Segmentation Plan (Deferred)

All services currently run on a flat 10.0.0.0/24 network. This works --
no services require VLAN segmentation to function. VLAN support is deferred
until VLAN-aware WiFi APs replace the Google Nest mesh.

**Prerequisites for VLANs:**
- Replace Google Nest WiFi with VLAN-aware APs (Ubiquiti UniFi U6 or TP-Link Omada EAP)
- VLAN-aware managed switch (assigns VLANs to physical ports)
- Dedicated router/firewall with VLAN support (e.g., OPNsense VM or UniFi Dream Machine)

**Target segmentation (when ready):**

| VLAN | Subnet         | Purpose           | Example Devices                    |
|------|----------------|-------------------|------------------------------------|
| 1    | 10.0.0.0/24    | Management        | Proxmox nodes, SSH, admin UIs      |
| 10   | 10.0.10.0/24   | Trusted LAN       | Workstations, laptops              |
| 20   | 10.0.20.0/24   | Servers           | K8s, LXCs, NAS, Traefik           |
| 30   | 10.0.30.0/24   | IoT               | Zigbee, Z-Wave, cameras, sensors   |
| 40   | 10.0.40.0/24   | Guest WiFi        | Visitors (internet only)           |

**Inter-VLAN firewall rules (future):**

```
Trusted (10) ---> Servers (20)     ALLOW   (access services)
Trusted (10) ---> IoT (30)         ALLOW   (manage devices)
IoT (30) -------> HA (10.0.0.31)   ALLOW   (smart home control)
IoT (30) -------> Servers (20)     DENY    (isolate compromised devices)
IoT (30) -------> Trusted (10)     DENY    (protect workstations)
Guest (40) -----> Internet         ALLOW   (internet only)
Guest (40) -----> ALL internal     DENY    (full isolation)
```

---

## Firewall Rules

### Port Forwarding (Google Nest WiFi Pro)

Configured via Google Home app > WiFi > Advanced Networking > Port Management.

| WAN Port | Destination        | Protocol | Purpose             |
|----------|--------------------|----------|---------------------|
| 80       | 10.0.0.20:80       | TCP      | HTTP -> Traefik     |
| 443      | 10.0.0.20:443      | TCP      | HTTPS -> Traefik    |

Google Nest handles NAT and basic firewall (blocks unsolicited inbound by default).
No advanced firewall rules, IDS/IPS, or VPN server available on consumer hardware.
For advanced firewall features, consider adding a dedicated firewall appliance in
the future (OPNsense VM or UniFi Dream Machine).

---

## Backup Strategy

| What                | Where                        | Method                          | Frequency  |
|---------------------|------------------------------|---------------------------------|------------|
| Proxmox VMs         | TrueNAS /pool/backups        | Proxmox backup job -> NFS       | Weekly     |
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
