# vm-opnsense.tf - OPNsense firewall/router VM
#
# Virtualized OPNsense firewall that replaces the consumer router.
# Becomes the network gateway for the entire homelab, handling:
#   - NAT / port forwarding (80/443 -> Traefik LXC)
#   - DHCP server with static leases for all infrastructure
#   - DNS resolver (Unbound) with local overrides for *.woodhead.tech
#   - Firewall rules and VLAN segmentation
#   - WireGuard VPN for remote access
#   - Cloudflare DDNS (built-in plugin, replaces custom script)
#   - Suricata IDS/IPS
#
# IMPORTANT: This VM needs TWO network interfaces:
#   - WAN: Connected to ISP modem/ONT (gets public IP via DHCP)
#   - LAN: Connected to vmbr0 (internal network, 10.0.0.0/24)
#
# The WAN interface can be either:
#   - A dedicated physical NIC passed through via PCI passthrough
#   - A second Proxmox bridge (vmbr1) connected to the ISP modem
#
# After OPNsense is configured, it becomes the default gateway (10.0.0.1)
# for all VMs, LXCs, and physical devices on the network.

resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense"
  node_name = var.proxmox_node
  vm_id     = var.opnsense_vmid
  tags      = ["infrastructure", "firewall", "opnsense"]

  description = "OPNsense firewall/router - network gateway for ${var.domain}"

  # q35 machine type with UEFI (OVMF) BIOS
  # q35 provides PCIe support needed for NIC passthrough and modern hardware.
  # UEFI boot is recommended by OPNsense for new installs.
  machine = "q35"

  bios = "ovmf"

  # EFI disk for UEFI boot (required when bios = ovmf)
  efi_disk {
    datastore_id = var.lxc_storage
    type         = "4m"
  }

  # Boot from OPNsense ISO for initial install
  cdrom {
    file_id = var.opnsense_iso
  }

  cpu {
    cores = var.opnsense_cores
    # host type for AES-NI support (needed for VPN/IPsec performance)
    type  = "host"
  }

  memory {
    dedicated = var.opnsense_memory
  }

  # OS disk -- local storage, not Ceph (router should survive Ceph issues)
  disk {
    datastore_id = var.lxc_storage  # Reuse local-lvm
    interface    = "scsi0"
    size         = var.opnsense_disk_size
    file_format  = "raw"
    ssd          = true
    discard      = "on"
  }

  # WAN interface -- connected to ISP modem/ONT
  # Uses a separate bridge (vmbr1) that is physically connected to the modem.
  # If using PCI passthrough instead, remove this block and pass through
  # the NIC via Proxmox host config (not Terraform).
  network_device {
    bridge = var.opnsense_wan_bridge
    model  = "virtio"
  }

  # LAN interface -- internal network
  # Connected to vmbr0 where all other VMs and LXCs live.
  # OPNsense assigns itself 10.0.0.1 on this interface.
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # No QEMU guest agent (FreeBSD-based, not standard Linux)
  agent {
    enabled = false
  }

  # Start on boot -- this is the network gateway, must come up first
  on_boot = true

  # Boot order: prioritize this VM to start before everything else
  startup {
    order    = 1
    up_delay = 30  # Give OPNsense 30s to initialize before starting other VMs
  }

  operating_system {
    type = "other" # FreeBSD-based
  }

  lifecycle {
    ignore_changes = [
      cdrom, # Ignore ISO changes after initial install
    ]
  }
}
