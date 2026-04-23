# lxc-traefik.tf - Traefik reverse proxy LXC container
#
# Front door for all inbound web traffic. Routes to K8s services
# and LXC containers based on hostname. Handles TLS via Let's Encrypt.

resource "proxmox_virtual_environment_container" "traefik" {
  node_name   = lookup(var.node_assignments, "traefik", var.proxmox_node)
  vm_id       = var.traefik_vmid
  description = "Traefik reverse proxy - front door for ${var.domain}"
  tags        = ["infrastructure", "traefik", var.domain]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = 1
    units = 2048  # Critical -- front door for all external traffic
  }

  memory {
    dedicated = 256
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 4
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  # Static IP, DNS, and SSH key for Ansible access
  initialization {
    hostname = "traefik"

    ip_config {
      ipv4 {
        address = "${var.traefik_ip}/${var.network_subnet}"
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
    # Proxmox returns dns.domain = " " (a space) when unset; provider bug.
    ignore_changes = [
      initialization[0].dns[0].domain,
    ]
  }
}
