# workers.tf - Worker node VM definitions

resource "proxmox_virtual_environment_vm" "worker" {
  count = var.worker_count

  name    = "${var.cluster_name}-worker-${count.index}"
  node_name = var.proxmox_node
  vm_id   = var.worker_vmid_start + count.index
  tags    = ["kubernetes", "worker", var.cluster_name]

  # Boot from Talos ISO
  cdrom {
    file_id = var.talos_iso
  }

  cpu {
    cores = var.worker_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.worker_memory
  }

  # OS disk on Ceph
  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.worker_disk_size
    file_format  = "raw"
    ssd          = true
    discard      = "on"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # Enable QEMU guest agent
  agent {
    enabled = true
  }

  on_boot = true

  # Serial console for Talos
  serial_device {}

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      cdrom,
    ]
  }
}
