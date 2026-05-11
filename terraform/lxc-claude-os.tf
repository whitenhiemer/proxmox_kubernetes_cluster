# lxc-claude-os.tf - Claude OS AI memory/knowledge system LXC
#
# Runs the Claude OS stack: FastAPI MCP server (8051), React frontend (5173),
# RQ workers, Redis, and optionally Ollama for local inference.
#
# After `terraform apply`, run: make claude-os OPENAI_API_KEY=sk-...
# Or for local Ollama: make claude-os INSTALL_OLLAMA=true

resource "proxmox_virtual_environment_container" "claude_os" {
  node_name   = lookup(var.node_assignments, "claude-os", var.proxmox_node)
  vm_id       = var.claude_os_vmid
  description = "Claude OS - persistent AI memory and knowledge management"
  tags        = ["service", "claude-os", "ai"]

  unprivileged  = true
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.debian_template
    type             = "debian"
  }

  cpu {
    cores = var.claude_os_cores
    units = 800
  }

  memory {
    dedicated = var.claude_os_memory
  }

  disk {
    datastore_id = var.lxc_storage
    size         = var.claude_os_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = "claude-os"

    ip_config {
      ipv4 {
        address = "${var.claude_os_ip}/${var.network_subnet}"
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
