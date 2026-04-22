# lxc-plex.tf - Plex Media Server LXC container
#
# Plex serves movies, TV shows, and music from the TrueNAS NFS share.
# Hardware transcoding uses Intel Quick Sync via /dev/dri passthrough
# (configured by the Ansible playbook on the Proxmox host).
#
# GPU passthrough requires the LXC to run on a Proxmox node with an
# Intel CPU that has an integrated GPU (iGPU). Pin this container to
# that node if your cluster has mixed hardware.
#
# Media is stored on TrueNAS and mounted via NFS at /media.
# Plex config/metadata lives on the LXC disk at /var/lib/plexmediaserver.

resource "proxmox_virtual_environment_container" "plex" {
  node_name   = var.proxmox_node
  vm_id       = var.plex_vmid
  description = "Plex Media Server - streaming for ${var.domain}"
  tags        = ["service", "media", "plex"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = var.plex_cores
  }

  memory {
    dedicated = var.plex_memory
  }

  disk {
    datastore_id = var.lxc_storage
    size         = var.plex_disk_size
  }

  network_interface {
    name = "eth0"
    ip_config {
      ipv4 {
        address = "${var.plex_ip}/${var.network_subnet}"
        gateway = var.network_gateway
      }
    }
  }

  # SSH key and DNS for Ansible access
  initialization {
    dns {
      servers = var.nameservers
    }

    user_account {
      keys = var.ssh_public_key != "" ? [var.ssh_public_key] : []
    }
  }

  # Nesting for device access
  features {
    nesting = true
  }
}
