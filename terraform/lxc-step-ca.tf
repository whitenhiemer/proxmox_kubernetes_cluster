# lxc-step-ca.tf - Smallstep step-ca LXC container
#
# SSH Certificate Authority for SSO access. Integrated with Authentik OIDC.

resource "proxmox_virtual_environment_container" "step_ca" {
  node_name   = lookup(var.node_assignments, "step_ca", var.proxmox_node)
  vm_id       = var.step_ca_vmid
  description = "Smallstep step-ca - SSH Certificate Authority for SSO"
  tags        = ["infrastructure", "security", "step-ca", var.domain]

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
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  # Static IP, DNS, and SSH key for Ansible access
  initialization {
    hostname = "step-ca"

    ip_config {
      ipv4 {
        address = "${var.step_ca_ip}/${var.network_subnet}"
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
