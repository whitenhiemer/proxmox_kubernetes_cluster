# TrueNAS Scale Setup Guide

Step-by-step guide for deploying TrueNAS Scale as the centralized NAS for the homelab.

## Prerequisites

- Proxmox VE running with at least one node
- Dedicated physical disks for ZFS pool (NOT shared with Ceph or local-lvm)
- Terraform and Ansible configured per the main RUNBOOK

## 1. Download the TrueNAS ISO

```bash
make prepare-truenas
```

This downloads TrueNAS Scale to the Proxmox ISO storage.

## 2. Plan Your Disk Layout

Before creating the VM, identify which physical disks will be passed through to TrueNAS.

On your Proxmox host:
```bash
# List all disks with model info
lsblk -d -o NAME,SIZE,MODEL,SERIAL

# Get stable disk IDs (these survive reboots)
ls -la /dev/disk/by-id/ | grep -v part
```

**Example layout** (3-disk system):
| Disk | Size | Purpose |
|------|------|---------|
| sda  | 500GB | Proxmox OS + local-lvm (Ceph OSD) |
| sdb  | 2TB  | TrueNAS ZFS pool (data disk 1) |
| sdc  | 2TB  | TrueNAS ZFS pool (data disk 2, mirror) |

**ZFS pool recommendations:**
- **Mirror** (2 disks): Best reliability for small setups, 50% usable space
- **RAIDZ1** (3+ disks): Single-parity, good balance of space and safety
- **Stripe** (any): Maximum space, zero redundancy -- only for replaceable data

## 3. Create the TrueNAS VM

```bash
# Preview the VM
cd terraform && terraform plan -target=proxmox_virtual_environment_vm.truenas

# Create it
make apply-truenas
```

## 4. Pass Through Data Disks

After the VM is created, pass through your data disks from the Proxmox host.
Terraform creates the OS disk (scsi0); data disks are added manually because they
reference physical hardware specific to your host.

```bash
# SSH into your Proxmox node
ssh root@10.0.0.10

# Pass through disks using their stable by-id path
# Replace <disk-id> with your actual disk IDs from step 2
qm set 300 -scsi1 /dev/disk/by-id/<disk-id-1>
qm set 300 -scsi2 /dev/disk/by-id/<disk-id-2>

# Verify the disks are attached
qm config 300 | grep scsi
```

**Why by-id?** Device names like `/dev/sdb` can change between reboots.
The `/dev/disk/by-id/` path is tied to the disk's serial number and stays stable.

## 5. Install TrueNAS Scale

1. Open the Proxmox web UI -> VM 300 (truenas) -> Console
2. Start the VM (it boots from the ISO)
3. Follow the text-mode installer:
   - Select the **OS disk** (the small 16GB disk, NOT your data disks)
   - Set the root/admin password
   - Choose BIOS boot mode
   - Let it install and reboot
4. After reboot, TrueNAS shows its web UI URL on the console

## 6. Initial TrueNAS Configuration

Access the web UI at `http://10.0.0.30` (or whatever IP it got via DHCP).

### Set Static IP
1. **Network** -> **Global Configuration**
   - Hostname: `truenas`
   - Domain: `woodhead.tech`
   - Nameserver 1: `10.0.0.1` (OPNsense)
   - Default Gateway: `10.0.0.1`
2. **Network** -> **Interfaces** -> Edit the active interface
   - Uncheck DHCP
   - Add alias: `10.0.0.30/24`
   - Save and test

### Create ZFS Storage Pool
1. **Storage** -> **Create Pool**
2. Name: `pool` (or `tank`, your preference)
3. Select your passthrough data disks (the 2TB+ drives, NOT the OS disk)
4. Choose layout: Mirror, RAIDZ1, or Stripe
5. Create the pool

### Create Media Dataset
The ARR stack, Plex, and Jellyfin all share this dataset.

1. **Datasets** -> Select your pool -> **Add Dataset**
   - Name: `media`
   - Record Size: 1M (optimal for large media files)
   - ACL Type: POSIX (simpler, works with NFS)
2. Create subdirectories via Shell or SSH:
   ```bash
   mkdir -p /mnt/pool/media/{downloads/complete,downloads/incomplete,movies,tv,music,books}
   ```

### Create NFS Share
1. **Shares** -> **Unix Shares (NFS)** -> **Add**
   - Path: `/mnt/pool/media`
   - Maproot User: `root`
   - Maproot Group: `wheel`
   - Authorized Networks: `10.0.0.0/24`
   - Save
2. **Services** -> Enable **NFS** -> Set to start automatically

### Set Permissions
The ARR stack runs as UID 1000 / GID 1000. Set ownership so containers can read/write:

```bash
# In TrueNAS Shell or SSH
chown -R 1000:1000 /mnt/pool/media
chmod -R 775 /mnt/pool/media
```

## 7. Connect the ARR Stack to NFS

Now that TrueNAS is serving NFS, re-run the ARR stack playbook with NFS parameters:

```bash
cd ansible && ansible-playbook playbooks/setup-arr-stack.yml \
  --extra-vars "nfs_server=10.0.0.30 nfs_share=/mnt/pool/media"
```

This mounts `10.0.0.30:/mnt/pool/media` at `/media` inside the ARR LXC and adds it
to fstab for persistence. All ARR containers (Sonarr, Radarr, SABnzbd, etc.) access
media at `/media/movies`, `/media/tv`, `/media/downloads`, etc.

### Verify the NFS Mount
```bash
# SSH into the ARR LXC
ssh root@10.0.0.22

# Check the mount
df -h /media
mount | grep nfs

# Verify the ARR user can write
sudo -u arrstack touch /media/downloads/test && rm /media/downloads/test
```

## 8. Additional NFS Shares (Optional)

You can create more datasets and shares for other purposes:

| Dataset | Path | Consumer | Notes |
|---------|------|----------|-------|
| `pool/media` | `/mnt/pool/media` | ARR, Plex, Jellyfin | Read/write for ARR, read-only for media players |
| `pool/backups` | `/mnt/pool/backups` | Proxmox, Home Assistant | VM backups, HA snapshots |
| `pool/isos` | `/mnt/pool/isos` | Proxmox | ISO storage, Proxmox NFS datastore |

### Add Proxmox NFS Datastore (optional)
Store ISOs and VM backups on TrueNAS instead of local disk:

```bash
# On Proxmox host
pvesm add nfs truenas-backups \
  --server 10.0.0.30 \
  --export /mnt/pool/backups \
  --content backup,iso \
  --options soft,intr
```

## 9. OPNsense DNS Override

Add a local DNS entry in OPNsense so `nas.woodhead.tech` resolves internally:

1. OPNsense -> **Services** -> **Unbound DNS** -> **Overrides** -> **Host Overrides**
2. Add: `nas` / `woodhead.tech` -> `10.0.0.30`

## 10. Enable QEMU Guest Agent

TrueNAS Scale supports the QEMU guest agent for clean shutdowns from Proxmox:

```bash
# In TrueNAS Shell or SSH
apt install -y qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent
```

## Verification Checklist

- [ ] VM 300 boots and shows TrueNAS web UI on console
- [ ] Static IP `10.0.0.30` is configured and reachable
- [ ] ZFS pool created with passthrough disks (check: `zpool status`)
- [ ] `/mnt/pool/media` dataset exists with correct subdirectories
- [ ] NFS share active (`showmount -e 10.0.0.30` from another host)
- [ ] ARR LXC mounts NFS at `/media` (`df -h /media` on 10.0.0.22)
- [ ] ARR containers can read/write media directories
- [ ] QEMU guest agent responds (`qm agent 300 ping` from Proxmox)

## Troubleshooting

### NFS mount fails on ARR LXC
```bash
# Test connectivity from ARR LXC
ping 10.0.0.30
showmount -e 10.0.0.30

# Check NFS service on TrueNAS
ssh root@10.0.0.30 "systemctl status nfs-server"

# Check firewall isn't blocking NFS (ports 111, 2049)
# If OPNsense is running, ensure NFS traffic is allowed on LAN
```

### Permission denied on media directories
```bash
# On TrueNAS, verify ownership matches ARR container UID
ls -la /mnt/pool/media/
# Should show 1000:1000

# Fix if needed
chown -R 1000:1000 /mnt/pool/media
```

### ZFS pool degraded
```bash
# Check pool status on TrueNAS
zpool status

# If a disk failed, replace it:
# 1. Identify the failed disk by serial number
# 2. Physically replace it (or add a new passthrough disk)
# 3. In TrueNAS UI: Storage -> Pool -> Manage Devices -> Replace
```
