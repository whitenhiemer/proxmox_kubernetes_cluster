# lxc-authelia.tf - Authelia SSO gateway LXC container
#
# Single LXC running Docker Compose with Authelia:
#   - Centralized authentication + authorization for all web services
#   - File-based user database with argon2id password hashing
#   - TOTP 2FA support (Google Authenticator, Authy)
#   - Integrates with Traefik via forwardAuth middleware
#
# Lightweight footprint: single Go binary, ~50MB RAM, SQLite session store.
# Nesting is enabled for Docker-in-LXC support.
# Secrets (JWT, session, storage encryption) are generated at deploy time.

resource "proxmox_virtual_environment_container" "authelia" {
  node_name   = lookup(var.node_assignments, "authelia", var.proxmox_node)
  vm_id       = var.authelia_vmid
  description = "Authelia - SSO authentication gateway"
  tags        = ["infrastructure", "auth", "security"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = 1
    units = 1200  # High -- auth gate blocks all protected services if slow
  }

  memory {
    dedicated = 1024
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
    hostname = "authelia"

    ip_config {
      ipv4 {
        address = "${var.authelia_ip}/${var.network_subnet}"
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

  # Nesting required for Docker-in-LXC
  features {
    nesting = true
  }
}
