# vm-homeassistant.tf - Home Assistant OS (HAOS) VM
#
# Home Assistant OS is a purpose-built OS for smart home automation.
# Unlike TrueNAS which boots from an ISO, HAOS ships as a pre-built
# disk image (qcow2) that Terraform downloads and imports directly.
#
# HAOS manages its own updates, addons, and backups. No Ansible config needed
# after the VM boots -- all setup happens through the HA web UI at :8123.
#
# Features:
#   - Addon support (Zigbee2MQTT, Node-RED, ESPHome, MQTT, etc.)
#   - Automatic OTA updates
#   - Built-in backup/restore
#   - Supervisor for managing the HA ecosystem
#
# USB passthrough for Zigbee/Z-Wave dongles (add after VM creation):
#   qm set 301 -usb0 host=<vendor>:<product>
#
# To find your dongle's vendor:product ID:
#   lsusb | grep -i "zigbee\|z-wave\|silicon\|texas\|dresden"

# HAOS disk image must be pre-downloaded and decompressed on the Proxmox host.
# The bpg/proxmox provider does not support xz decompression -- only gz, lzo, zst.
# HAOS ships as .qcow2.xz, so we handle it out of band:
#
#   1. Download:  wget -P /var/lib/vz/template/cache/ <haos_url>
#   2. Decompress: xz -d /var/lib/vz/template/cache/haos_ova-*.qcow2.xz
#   3. Copy:      cp /var/lib/vz/template/cache/haos_ova-*.qcow2 /var/lib/vz/template/iso/haos-ova.qcow2
#   4. Run:       make apply-homeassistant
#
# Terraform references the decompressed qcow2 directly from local ISO storage.

resource "proxmox_virtual_environment_vm" "homeassistant" {
  name      = "homeassistant"
  node_name = var.proxmox_node
  vm_id     = var.homeassistant_vmid
  tags      = ["infrastructure", "smarthome", "homeassistant"]

  description = "Home Assistant OS - smart home automation for ${var.domain}"

  # q35 machine type with UEFI boot (recommended for HAOS)
  machine = "q35"
  bios    = "ovmf"

  # EFI disk for UEFI boot (required when bios = ovmf)
  efi_disk {
    datastore_id = var.lxc_storage
    type         = "4m"
  }

  cpu {
    cores = var.homeassistant_cores
    # host type for USB passthrough and hardware access
    type  = "host"
    units = 800  # Low priority -- mostly idle automations
  }

  memory {
    dedicated = var.homeassistant_memory           # Ceiling: max RAM available
    floating  = var.homeassistant_balloon          # Floor: minimum guaranteed RAM (enables ballooning)
  }

  # HAOS boot disk -- Terraform creates a blank disk, then the HAOS qcow2 is
  # imported via 'qm importdisk' after VM creation. The lifecycle block below
  # ignores disk changes so Terraform won't revert the import.
  #
  # After 'make apply-homeassistant', run:
  #   qm importdisk 301 /var/lib/vz/template/iso/haos-ova.qcow2 local-lvm
  #   qm set 301 -scsi0 local-lvm:vm-301-disk-1
  #   qm set 301 -boot order=scsi0
  disk {
    datastore_id = var.lxc_storage
    interface    = "scsi0"
    size         = var.homeassistant_disk_size
    file_format  = "raw"
    discard      = "on"
    ssd          = true
  }

  # LAN interface -- same network as all other services
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # HAOS includes the QEMU guest agent
  # Timeout capped to prevent Terraform from hanging on state refresh.
  agent {
    enabled = true
    timeout = "15s"
  }

  # Start on boot -- smart home should always be running
  on_boot = true

  # Boot after TrueNAS (1)
  startup {
    order    = 2
    up_delay = 15
  }

  operating_system {
    type = "l26"  # Linux kernel (HAOS is Linux-based)
  }

  # Serial console for headless access via Proxmox UI
  serial_device {}

  lifecycle {
    ignore_changes = [
      # HAOS manages its own disk (resizes during updates, etc.)
      # Don't let Terraform fight with HAOS internal disk changes.
      disk,
    ]
  }
}
