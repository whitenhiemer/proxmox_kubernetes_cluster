# control-plane.tf - Control plane VM definitions

resource "proxmox_virtual_environment_vm" "controlplane" {
  count = var.controlplane_count

  name      = "${var.cluster_name}-cp-${count.index}"
  # Spread control plane VMs across Proxmox hosts for HA.
  # Falls back to proxmox_node if controlplane_nodes is not set.
  node_name = length(var.controlplane_nodes) > count.index ? var.controlplane_nodes[count.index] : var.proxmox_node
  vm_id   = var.controlplane_vmid_start + count.index
  tags    = ["kubernetes", "controlplane", var.cluster_name]

  # Boot from Talos ISO
  cdrom {
    file_id = var.talos_iso
  }

  cpu {
    cores = var.controlplane_cores
    type  = "x86-64-v2-AES"
    units = 1200  # High priority -- cluster control plane
  }

  memory {
    dedicated = var.controlplane_memory          # Ceiling: max RAM available
    floating  = var.controlplane_balloon         # Floor: minimum guaranteed RAM (enables ballooning)
    # Note: memory shares (ivshmem) requires root@pam auth, not API tokens.
    # Set shares via Proxmox UI or CLI: qm set <vmid> -shares <value>
  }

  # OS disk on Ceph
  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.controlplane_disk_size
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

  # Ensure VMs start on boot
  on_boot = true

  # Serial console for Talos
  serial_device {}

  operating_system {
    type = "l26" # Linux 2.6+ kernel
  }

  lifecycle {
    ignore_changes = [
      cdrom, # Ignore ISO changes after initial boot
    ]
  }
}
