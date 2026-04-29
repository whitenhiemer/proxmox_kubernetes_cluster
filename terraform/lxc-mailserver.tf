# lxc-mailserver.tf - Mailcow email server LXC container
#
# Runs the full Mailcow stack (Postfix, Dovecot, Rspamd, SOGo webmail,
# MariaDB, Redis) via Docker Compose. Handles mail for woodhead.tech.
# Outbound relay via Mailgun (ISP blocks port 25).
#
# Nesting enabled for Docker-in-LXC support.

resource "proxmox_virtual_environment_container" "mailserver" {
  node_name   = lookup(var.node_assignments, "mailserver", var.proxmox_node)
  vm_id       = var.mailserver_vmid
  description = "Mailcow email server for woodhead.tech"
  tags        = ["service", "mailserver"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = var.mailserver_cores
    units = 1024
  }

  memory {
    dedicated = var.mailserver_memory
  }

  disk {
    datastore_id = var.lxc_storage
    size         = var.mailserver_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "mailserver"

    ip_config {
      ipv4 {
        address = "${var.mailserver_ip}/${var.network_subnet}"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.nameservers
    }

    user_account {
      keys     = var.ssh_public_key != "" ? [var.ssh_public_key] : []
      password = var.mailserver_root_password
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
