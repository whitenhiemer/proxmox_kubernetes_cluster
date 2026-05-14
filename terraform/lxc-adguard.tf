# lxc-adguard.tf - AdGuard Home LXC container
#
# Internal DNS server with ad blocking for the homelab LAN.
# Handles DNS rewrites (workstation hostnames, internal services),
# ad blocking, and DNS-over-HTTPS upstream resolution.
# Configure Google Nest to use this LXC as upstream DNS after deploy.

resource "proxmox_virtual_environment_container" "adguard" {
  node_name   = lookup(var.node_assignments, "adguard", var.proxmox_node)
  vm_id       = var.adguard_vmid
  description = "AdGuard Home - internal DNS + ad blocking for ${var.domain}"
  tags        = ["infrastructure", "dns", var.domain]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = 1
    units = 1024
  }

  memory {
    dedicated = 512
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 4
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "adguard"

    ip_config {
      ipv4 {
        address = "${var.adguard_ip}/${var.network_subnet}"
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
