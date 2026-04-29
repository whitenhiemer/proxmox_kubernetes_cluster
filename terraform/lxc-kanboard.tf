# lxc-kanboard.tf - Kanboard project management LXC container
#
# Single LXC running Docker Compose with the official Kanboard image.
# SQLite-backed task board at tasks.woodhead.tech, protected by Authentik.
# ClawBot polls the Kanboard JSON-RPC API for async task processing.
#
# Nesting enabled for Docker-in-LXC support.

resource "proxmox_virtual_environment_container" "kanboard" {
  node_name   = lookup(var.node_assignments, "kanboard", var.proxmox_node)
  vm_id       = var.kanboard_vmid
  description = "Kanboard project management"
  tags        = ["service", "kanboard"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = 1
    units = 512
  }

  memory {
    dedicated = 512
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "kanboard"

    ip_config {
      ipv4 {
        address = "${var.kanboard_ip}/${var.network_subnet}"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.nameservers
    }

    user_account {
      keys     = var.ssh_public_key != "" ? [var.ssh_public_key] : []
      password = var.kanboard_root_password
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
