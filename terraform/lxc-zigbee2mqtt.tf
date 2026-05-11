# lxc-zigbee2mqtt.tf - Zigbee2MQTT + Mosquitto LXC
#
# Bridges the Zigbee USB dongle (attached to zotac) into Home Assistant via MQTT.
# Must live on zotac — USB passthrough only works on the same physical host.
#
# After `terraform apply`, run: make zigbee2mqtt

resource "proxmox_virtual_environment_container" "zigbee2mqtt" {
  node_name   = "zotac"
  vm_id       = var.zigbee2mqtt_vmid
  description = "Zigbee2MQTT + Mosquitto - bridges Zigbee USB dongle to Home Assistant via MQTT"
  tags        = ["service", "zigbee", "iot"]

  unprivileged  = false   # privileged required for USB device passthrough in Docker
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
    hostname = "zigbee2mqtt"

    ip_config {
      ipv4 {
        address = "${var.zigbee2mqtt_ip}/${var.network_subnet}"
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
