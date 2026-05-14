# lxc-minecraft.tf - Minecraft Java Edition server LXC
#
# PaperMC server for family use. World data lives in /opt/minecraft/data
# inside the LXC; back up to TrueNAS manually or via a cron snapshot.

resource "proxmox_virtual_environment_container" "minecraft" {
  node_name   = lookup(var.node_assignments, "minecraft", var.proxmox_node)
  vm_id       = var.minecraft_vmid
  description = "Minecraft Java Edition server (PaperMC) — Annie's server"
  tags        = ["games", "minecraft", var.domain]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = 2
    units = 1024
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 10
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "minecraft"

    ip_config {
      ipv4 {
        address = "${var.minecraft_ip}/${var.network_subnet}"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.nameservers
    }

    user_account {
      keys = var.ssh_public_key != "" ? [var.ssh_public_key] : []
    }
  }

  features {
    nesting = true
  }

  lifecycle {
    ignore_changes = [
      initialization[0].dns[0].domain,
    ]
  }
}
