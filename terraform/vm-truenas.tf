# vm-truenas.tf - TrueNAS Scale NAS VM
#
# TrueNAS Scale provides centralized network storage (NFS/SMB) for the homelab.
# It manages ZFS pools on dedicated physical disks passed through from Proxmox.
#
# Storage consumers:
#   - ARR stack: NFS mount at /media for movies, TV, music, downloads
#   - Plex / Jellyfin: NFS mount for media library (read-only)
#   - Home Assistant: NFS mount for backups
#   - Proxmox: optional NFS datastore for ISOs and backups
#
# IMPORTANT: TrueNAS needs dedicated physical disks for its ZFS pool.
# These are NOT the same disks used by Ceph or local-lvm. You must pass
# through raw disks after the VM is created:
#
#   # List available disks on the Proxmox host
#   lsblk -d -o NAME,SIZE,MODEL
#
#   # Pass through a disk by its stable ID (survives reboots)
#   qm set 300 -scsi1 /dev/disk/by-id/<disk-id>
#   qm set 300 -scsi2 /dev/disk/by-id/<disk-id>
#
# The OS disk (scsi0) is on local-lvm. Data disks (scsi1+) are passthrough.
# TrueNAS will create a ZFS pool from the passthrough disks during setup.

resource "proxmox_virtual_environment_vm" "truenas" {
  name      = "truenas"
  node_name = var.proxmox_node
  vm_id     = var.truenas_vmid
  tags      = ["infrastructure", "storage", "truenas"]

  description = "TrueNAS Scale NAS - centralized storage for ${var.domain}"

  # Standard i440fx with BIOS boot -- TrueNAS Scale installs fine without UEFI
  bios = "seabios"

  # Boot from TrueNAS ISO for initial install
  cdrom {
    file_id = var.truenas_iso
  }

  cpu {
    cores = var.truenas_cores
    # host type for optimal ZFS performance (AES-NI, AVX for checksums)
    type  = "host"
  }

  memory {
    # TrueNAS/ZFS benefits heavily from RAM -- ARC cache uses ~1GB per TB of storage.
    # 8GB minimum, 16GB+ recommended for a media NAS with multiple consumers.
    dedicated = var.truenas_memory
  }

  # OS disk -- local storage, separate from the ZFS data pool
  # TrueNAS Scale installs its Debian-based OS here (~4GB used).
  # Keep this small -- all user data goes on the ZFS pool (passthrough disks).
  disk {
    datastore_id = var.lxc_storage  # local-lvm
    interface    = "scsi0"
    size         = var.truenas_disk_size
    file_format  = "raw"
    ssd          = true
    discard      = "on"
  }

  # LAN interface -- same network as all other services
  # TrueNAS gets a static IP configured during install or via the console.
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # QEMU guest agent -- TrueNAS Scale is Debian-based, supports it
  agent {
    enabled = true
  }

  # Start on boot -- other services depend on NFS shares from this VM
  on_boot = true

  # Boot early -- other services depend on NFS shares from this VM
  startup {
    order    = 1
    up_delay = 30  # Give TrueNAS time to mount ZFS pools and start NFS
  }

  operating_system {
    type = "l26"  # Linux 2.6+ kernel (TrueNAS Scale is Debian-based)
  }

  # Serial console for headless access via Proxmox UI
  serial_device {}

  lifecycle {
    ignore_changes = [
      cdrom,  # Ignore ISO changes after initial install
    ]
  }
}
