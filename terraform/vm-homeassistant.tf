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

# Download HAOS disk image to Proxmox storage
# The provider handles .xz decompression automatically.
# This runs once -- subsequent applies skip the download if the file exists.
resource "proxmox_virtual_environment_download_file" "haos_image" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = var.proxmox_node
  url                     = var.homeassistant_image_url
  file_name               = "haos-ova.qcow2"
  decompression_algorithm = "xz"
}

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
  }

  memory {
    dedicated = var.homeassistant_memory
  }

  # HAOS boot disk -- imported from the downloaded qcow2 image
  # Terraform downloads the image via proxmox_virtual_environment_download_file
  # and imports it as the VM's primary disk.
  disk {
    datastore_id = var.lxc_storage
    interface    = "scsi0"
    file_id      = proxmox_virtual_environment_download_file.haos_image.id
    size         = var.homeassistant_disk_size
    discard      = "on"
    ssd          = true
  }

  # LAN interface -- same network as all other services
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # HAOS includes the QEMU guest agent
  agent {
    enabled = true
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
