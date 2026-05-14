# workers.tf - Worker node VM definitions

resource "proxmox_virtual_environment_vm" "worker" {
  count = var.worker_count

  name      = "${var.cluster_name}-worker-${count.index}"
  # Spread worker VMs across Proxmox hosts for anti-affinity.
  # Falls back to proxmox_node if worker_nodes is not set.
  node_name = length(var.worker_nodes) > count.index ? var.worker_nodes[count.index] : var.proxmox_node
  vm_id   = var.worker_vmid_start + count.index
  tags    = ["kubernetes", "worker", var.cluster_name]

  # Boot from Talos ISO
  cdrom {
    file_id = var.talos_iso
  }

  cpu {
    cores = var.worker_cores
    type  = "x86-64-v2-AES"
    units = 1024  # Normal priority -- pod workloads
  }

  memory {
    dedicated = var.worker_memory          # Ceiling: max RAM available
    floating  = var.worker_balloon         # Floor: minimum guaranteed RAM (enables ballooning)
  }

  # OS disk on Ceph
  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.worker_disk_size
    file_format  = "raw"
    ssd          = true
    discard      = "on"
    iothread     = true

    speed {
      iops_read  = var.talos_iops_read
      iops_write = var.talos_iops_write
    }
  }


  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # QEMU guest agent -- Talos doesn't run the agent, but enabling it
  # lets Proxmox detect it if a future Talos version adds support.
  # Timeout capped to prevent Terraform from hanging on state refresh.
  agent {
    enabled = true
    timeout = "15s"
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
