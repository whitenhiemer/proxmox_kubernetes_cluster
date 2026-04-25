# lxc-authelia.tf - Authentik identity provider LXC container
#
# Single LXC running Docker Compose with Authentik:
#   - Full identity provider: OIDC, SAML, proxy auth
#   - PostgreSQL 16 + Redis + Authentik server + worker
#   - Integrates with Traefik via forwardAuth middleware
#
# Requires 2GB RAM for the full stack (Postgres + Redis + server + worker).
# Nesting is enabled for Docker-in-LXC support.
# Secrets are generated at deploy time and stored in /opt/authentik/.env.

resource "proxmox_virtual_environment_container" "authelia" {
  node_name   = lookup(var.node_assignments, "authelia", var.proxmox_node)
  vm_id       = var.authelia_vmid
  description = "Authentik - identity provider (SSO, OIDC, proxy auth)"
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
    dedicated = 2048
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
    hostname = "authentik"

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

  lifecycle {
    # Proxmox returns dns.domain = " " (a space) when unset; provider bug.
    ignore_changes = [
      initialization[0].dns[0].domain,
    ]
  }
}
