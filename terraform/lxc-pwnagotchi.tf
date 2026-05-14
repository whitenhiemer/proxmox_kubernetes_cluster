# lxc-pwnagotchi.tf - Pwnagotchi WiFi learning device LXC
#
# Runs pwnagotchi (bettercap + Python AI) for passive WiFi handshake capture.
# MUST live on pve3 (thinkcentre3) — TP-Link TL-WN722N v2 WiFi dongle is
# physically attached there. WiFi interface is passed into the LXC via
# lxc.net.1.type=phys (configured by setup-pwnagotchi.yml Play 1).
#
# After `terraform apply`, run: make pwnagotchi

resource "proxmox_virtual_environment_container" "pwnagotchi" {
  node_name   = "thinkcentre3"
  vm_id       = var.pwnagotchi_vmid
  description = "Pwnagotchi - passive WiFi handshake capture (RTL8188EUS on pve3)"
  tags        = ["service", "security", "wifi"]

  unprivileged  = false  # privileged required for WiFi monitor mode passthrough
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
    dedicated = 1024
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
    hostname = "pwnagotchi"

    ip_config {
      ipv4 {
        address = "${var.pwnagotchi_ip}/${var.network_subnet}"
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

  lifecycle {
    ignore_changes = [
      initialization[0].dns[0].domain,
    ]
  }
}
