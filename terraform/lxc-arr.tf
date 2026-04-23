# lxc-arr.tf - ARR media management stack LXC container
#
# Single LXC running Docker Compose with the full ARR stack:
#   - Prowlarr (indexer manager)
#   - Sonarr (TV shows)
#   - Radarr (movies)
#   - Bazarr (subtitles)
#   - Overseerr (user-facing request portal)
#   - SABnzbd (Usenet downloader)
#   - Gluetun (VPN container for download traffic)
#
# All services share the same network namespace via Docker Compose,
# so they communicate over localhost. Media storage is mounted from
# TrueNAS via NFS (configured in the Ansible playbook after NAS deploy).
#
# Nesting is enabled for Docker-in-LXC support.
# The container needs more resources than typical LXCs because it runs
# multiple services simultaneously.

resource "proxmox_virtual_environment_container" "arr" {
  node_name   = lookup(var.node_assignments, "arr", var.proxmox_node)
  vm_id       = var.arr_vmid
  description = "ARR media stack - sonarr/radarr/prowlarr/bazarr/overseerr"
  tags        = ["service", "arr-stack", "media"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = var.arr_cores
    units = 1024  # Normal -- background downloads and indexing
  }

  memory {
    dedicated = var.arr_memory
  }

  disk {
    datastore_id = var.lxc_storage
    size         = var.arr_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  # Static IP, DNS, and SSH key for Ansible access
  initialization {
    hostname = "arr-stack"

    ip_config {
      ipv4 {
        address = "${var.arr_ip}/${var.network_subnet}"
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
