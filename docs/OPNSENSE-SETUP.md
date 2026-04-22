# OPNsense Setup Guide

Complete guide for deploying OPNsense as a virtualized firewall/router on Proxmox.
After setup, OPNsense replaces your consumer router as the network gateway.

## Prerequisites

- Proxmox VE 8.x with base setup complete (`make setup`)
- Two network paths to the ISP modem:
  - **Option A (recommended)**: Two physical NICs -- one for Proxmox management, one for WAN
  - **Option B**: Single NIC with VLAN tagging to separate WAN and LAN
- ISP modem/ONT in bridge mode (or at minimum, know its DHCP range)

## Step 1: Prepare Proxmox Networking

### Option A: Dedicated WAN NIC (two physical NICs)

Your Proxmox host needs a second bridge for the WAN interface. SSH into the
Proxmox node and edit `/etc/network/interfaces`:

```bash
# Existing LAN bridge (already configured during Proxmox install)
auto vmbr0
iface vmbr0 inet static
    address 10.0.0.10/24
    gateway 10.0.0.1    # Will point to OPNsense after setup
    bridge-ports eno1    # Your LAN NIC
    bridge-stp off
    bridge-fd 0

# NEW: WAN bridge for OPNsense
# Connected to the physical NIC going to the ISP modem.
# No IP address -- OPNsense handles WAN addressing.
auto vmbr1
iface vmbr1 inet manual
    bridge-ports eno2    # Your WAN NIC (connected to ISP modem)
    bridge-stp off
    bridge-fd 0
```

Apply the changes:
```bash
ifreload -a
# Or reboot if ifreload isn't available
```

### Option B: Single NIC with VLANs

If you only have one physical NIC, use VLAN tagging. This is more complex
and requires a VLAN-aware switch between Proxmox and the ISP modem.

```bash
# VLAN-aware bridge (single NIC)
auto vmbr0
iface vmbr0 inet static
    address 10.0.0.10/24
    gateway 10.0.0.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

Then assign VLAN tags to the OPNsense VM NICs in Terraform/Proxmox.

## Step 2: Download OPNsense ISO

```bash
make prepare-opnsense
```

This downloads the OPNsense DVD ISO to Proxmox storage via Ansible.

## Step 3: Create the VM

```bash
# Create just the OPNsense VM
make apply-opnsense

# Or create everything at once
make init && make apply
```

The Terraform config creates a VM with:
- **VM ID**: 100 (highest boot priority)
- **Machine**: q35 with UEFI (OVMF) BIOS
- **CPU**: 2 cores, host type (for AES-NI)
- **RAM**: 4GB
- **Disk**: 16GB on local-lvm
- **NIC 1** (net0): WAN on vmbr1
- **NIC 2** (net1): LAN on vmbr0
- **Boot order**: 1 (starts before all other VMs, 30s head start)

## Step 4: Install OPNsense

1. Open the Proxmox web UI console for the OPNsense VM
2. Boot from the ISO -- you'll see the OPNsense live environment
3. Log in with: `installer` / `opnsense`
4. Follow the installer:
   - Select UFS or ZFS (UFS is fine for 16GB)
   - Select the target disk (usually `da0`)
   - Set a root password
   - Complete the install and reboot
5. **Remove the ISO** after install:
   - In Proxmox UI: VM > Hardware > CD/DVD > Do not use any media

## Step 5: Initial Network Configuration

After reboot, OPNsense drops to a console menu. You need to assign interfaces.

### 5.1 Assign Interfaces

At the console menu, select option `1) Assign interfaces`:

```
Do you want to configure LAGGs now? [y/N]: N
Do you want to configure VLANs now? [y/N]: N

Enter the WAN interface name: vtnet0    (first NIC = vmbr1 = WAN)
Enter the LAN interface name: vtnet1    (second NIC = vmbr0 = LAN)
```

**IMPORTANT**: The NIC order matches the Terraform config:
- `vtnet0` = first `network_device` block = WAN (vmbr1)
- `vtnet1` = second `network_device` block = LAN (vmbr0)

### 5.2 Set LAN IP

Select option `2) Set interface IP address`, then `2) LAN`:

```
Configure IPv4 via DHCP? [y/N]: N
Enter the new LAN IPv4 address: 10.0.0.1
Enter the new LAN IPv4 subnet: 24
For a WAN, enter the new upstream gateway: (leave blank for LAN)
Configure IPv6 via DHCP6? [y/N]: N
Do you want to enable the DHCP server on LAN? [y/N]: y
Enter the start address of the client range: 10.0.0.200
Enter the end address of the client range: 10.0.0.254
Do you want to change the web GUI protocol from HTTPS to HTTP? [y/N]: N
```

### 5.3 Set WAN to DHCP

Select option `2) Set interface IP address`, then `1) WAN`:

```
Configure IPv4 via DHCP? [Y/n]: Y
Configure IPv6 via DHCP6? [y/N]: N
```

The WAN interface will get a public IP from your ISP modem.

### 5.4 Access the Web UI

From a machine on the LAN (10.0.0.0/24):
```
https://10.0.0.1
```

Default login: `root` / (the password you set during install)

## Step 6: Web UI Configuration

### 6.1 Setup Wizard

OPNsense runs a setup wizard on first web login:

1. **General**: Set hostname (`opnsense`), domain (`woodhead.tech`), DNS servers (`1.1.1.1`, `8.8.8.8`)
2. **Time**: Set timezone and NTP server
3. **WAN**: Confirm DHCP (should already be configured)
4. **LAN**: Confirm 10.0.0.1/24
5. **Root password**: Confirm or change
6. **Reload**: Apply settings

### 6.2 Port Forwarding (Traefik)

Navigate to **Firewall > NAT > Port Forward**, add two rules:

| Protocol | Dest Port | NAT IP    | NAT Port | Description        |
|----------|-----------|-----------|----------|--------------------|
| TCP      | 80        | 10.0.0.20 | 80       | HTTP -> Traefik    |
| TCP      | 443       | 10.0.0.20 | 443      | HTTPS -> Traefik   |

This replaces the consumer router's port forwarding.

### 6.3 Static DHCP Leases

Navigate to **Services > DHCPv4 > [LAN]**, scroll to "DHCP Static Mappings".
Add entries for all infrastructure:

| MAC Address   | IP          | Hostname               |
|---------------|-------------|------------------------|
| (traefik)     | 10.0.0.20   | traefik                |
| (recipe-site) | 10.0.0.21   | recipe-site            |
| (pve1)        | 10.0.0.10   | pve1                   |
| (pve2)        | 10.0.0.11   | pve2                   |

Note: K8s VMs and LXCs use static IPs from Terraform, but DHCP leases
serve as a backup and for MAC-to-IP documentation.

### 6.4 DNS Local Overrides (Unbound)

Navigate to **Services > Unbound DNS > Overrides**. Add host overrides so
internal clients resolve woodhead.tech subdomains to internal IPs (skips
Cloudflare, faster, works during internet outages):

| Host      | Domain        | IP          |
|-----------|---------------|-------------|
| recipes   | woodhead.tech | 10.0.0.20   |
| traefik   | woodhead.tech | 10.0.0.20   |
| nas       | woodhead.tech | 10.0.0.30   |
| home      | woodhead.tech | 10.0.0.31   |
| *         | woodhead.tech | 10.0.0.20   |

The wildcard (`*`) sends all unmatched subdomains to Traefik.

### 6.5 Cloudflare DDNS

Navigate to **Services > Dynamic DNS**, add a new entry:

| Setting          | Value                                |
|------------------|--------------------------------------|
| Service          | Cloudflare                           |
| Username         | (leave blank for token auth)         |
| Password         | Your Cloudflare API token            |
| Zone             | woodhead.tech                        |
| Hostname         | woodhead.tech                        |
| Check IP method  | Interface (WAN)                      |
| Interface        | WAN                                  |

Add a second entry for `*.woodhead.tech` with the same settings.

This replaces the `scripts/ddns/cloudflare-ddns.sh` cron job. Once
OPNsense DDNS is configured, you can remove the cron-based updater.

### 6.6 WireGuard VPN (Remote Access)

Navigate to **VPN > WireGuard**:

1. **Local** tab: Create a new instance
   - Name: `wg0`
   - Listen port: `51820`
   - Tunnel address: `10.10.0.1/24` (VPN subnet, separate from LAN)
   - Generate keypair
2. **Peers** tab: Add your devices
   - Public key: from your device's WireGuard config
   - Allowed IPs: `10.10.0.2/32` (one IP per device)
3. **Firewall > Rules > WireGuard**: Allow traffic from VPN subnet
4. **Firewall > NAT > Port Forward**: Forward UDP 51820 to OPNsense

Client config (on your Mac/phone):
```ini
[Interface]
PrivateKey = <your-device-private-key>
Address = 10.10.0.2/24
DNS = 10.0.0.1

[Peer]
PublicKey = <opnsense-public-key>
AllowedIPs = 10.0.0.0/24, 10.10.0.0/24
Endpoint = woodhead.tech:51820
PersistentKeepalive = 25
```

### 6.7 Suricata IDS/IPS (Optional)

Navigate to **Services > Intrusion Detection**:

1. Enable IDS
2. Select rulesets: ET Open, Abuse.ch
3. Pattern matcher: Hyperscan (if CPU supports it)
4. Set to IPS mode for active blocking (or IDS for monitoring only)
5. Apply to WAN interface

Note: IPS mode requires more CPU. With 2 cores and Suricata active,
consider bumping to 4 cores if you see performance issues.

## Step 7: VLAN Setup (Optional, Future)

Once the base setup is working, add VLANs for network segmentation.
See the VLAN plan in [ROADMAP.md](ROADMAP.md).

Navigate to **Interfaces > Other Types > VLAN**:

1. Create VLANs on the LAN parent interface
2. Assign each VLAN as a new interface
3. Configure DHCP on each VLAN subnet
4. Add firewall rules between VLANs

This requires a VLAN-aware switch (managed switch) connected to vmbr0.

## Step 8: Cutover from Consumer Router

Once OPNsense is fully configured and tested:

1. Disconnect ISP modem from consumer router
2. Connect ISP modem to the Proxmox NIC assigned to vmbr1
3. Verify OPNsense gets a WAN IP: **Interfaces > Overview**
4. Update Proxmox nodes' default gateway to 10.0.0.1 (if not already)
5. Verify internet access from LAN devices
6. Power off the consumer router

## Backup

Export OPNsense config regularly:
- **System > Configuration > Backups > Download configuration**
- Store the XML file on TrueNAS or in a git repo (it's small, ~50KB)
- OPNsense also supports automatic Google Drive/Nextcloud backups
