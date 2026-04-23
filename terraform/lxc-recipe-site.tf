# lxc-recipe-site.tf - Recipe site LXC container
#
# Provisions a Debian 12 LXC container for the House Woodward Gourmand
# recipe site (Go + SQLite). After Terraform creates the container,
# Ansible runs the install script inside it (make recipe-site).
#
# The recipe site serves HTTP on port 80 (nginx -> Go app on :8080).
# TLS is terminated upstream by the Traefik LXC.

resource "proxmox_virtual_environment_container" "recipe_site" {
  node_name   = lookup(var.node_assignments, "recipe_site", var.proxmox_node)
  vm_id       = var.recipe_site_vmid
  description = "Recipe site - recipes.${var.domain}"
  tags        = ["service", "recipe-site", var.domain]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = 1
    units = 512  # Minimal -- static Go binary, near-zero CPU
  }

  memory {
    # 2GB needed for Go compilation of modernc.org/sqlite (CGo-free)
    dedicated = 2048
  }

  disk {
    datastore_id = var.lxc_storage
    # 8GB: Go toolchain (~500MB) + app + SQLite DB + headroom
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  # Static IP, DNS, and SSH key for Ansible access
  initialization {
    hostname = "recipe-site"

    ip_config {
      ipv4 {
        address = "${var.recipe_site_ip}/${var.network_subnet}"
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
}
