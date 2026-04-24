# lxc-ssh-hook.tf - Hook script to fix SSH socket activation on Debian 12.12+
#
# Debian 12.12 uses systemd socket activation for SSH, which only binds to
# IPv6 by default. This hook script runs after the LXC container starts and
# disables socket activation so sshd listens on 0.0.0.0 (IPv4) directly.

resource "proxmox_virtual_environment_file" "lxc_ssh_fix" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    file_name = "lxc-ssh-fix.sh"
    data      = <<-EOF
      #!/bin/bash
      # Fix SSH socket activation on Debian 12.12+ LXC containers.
      # Socket activation binds to IPv6 only; disable it so sshd listens on IPv4.
      phase="$1"
      vmid="$2"
      if [ "$phase" = "post-start" ]; then
          sleep 3
          pct exec "$vmid" -- bash -c "
              systemctl stop ssh.socket 2>/dev/null || true
              systemctl disable ssh.socket 2>/dev/null || true
              systemctl restart ssh
          " 2>/dev/null || true
      fi
    EOF
  }
}
