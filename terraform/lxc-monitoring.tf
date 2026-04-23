# lxc-monitoring.tf - Monitoring stack LXC container
#
# Single LXC running Docker Compose with the full monitoring stack:
#   - Prometheus (metrics storage + scrape engine)
#   - Grafana (dashboards + visualization)
#   - Alertmanager (alert routing to Discord/Slack)
#   - Node Exporter (host metrics for this LXC)
#   - cAdvisor (Docker container metrics)
#   - Blackbox Exporter (HTTP/ICMP probes for all services)
#   - PVE Exporter (Proxmox host/VM/LXC metrics via API)
#
# Grafana is exposed via Traefik at grafana.woodhead.tech.
# Prometheus scrapes all infrastructure targets (Proxmox hosts, LXCs, VMs,
# K8s cluster, Docker containers, and service health probes).
#
# Nesting is enabled for Docker-in-LXC support.
# 20 GB disk accommodates ~30 days of Prometheus TSDB at 15s intervals.

resource "proxmox_virtual_environment_container" "monitoring" {
  node_name   = lookup(var.node_assignments, "monitoring", var.proxmox_node)
  vm_id       = var.monitoring_vmid
  description = "Monitoring stack - Prometheus/Grafana/Alertmanager"
  tags        = ["infrastructure", "monitoring", "grafana"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = var.monitoring_cores
  }

  memory {
    dedicated = var.monitoring_memory
  }

  disk {
    datastore_id = var.lxc_storage
    size         = var.monitoring_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  # Static IP, DNS, and SSH key for Ansible access
  initialization {
    hostname = "monitoring"

    ip_config {
      ipv4 {
        address = "${var.monitoring_ip}/${var.network_subnet}"
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
