# vm-opnsense-variables.tf - Variables for the OPNsense firewall/router VM

variable "opnsense_vmid" {
  description = "VM ID for the OPNsense firewall (low ID = high priority)"
  type        = number
  default     = 100
}

variable "opnsense_iso" {
  description = "Path to OPNsense ISO on Proxmox storage (e.g., local:iso/OPNsense-24.7-dvd-amd64.iso)"
  type        = string
  default     = "local:iso/OPNsense-dvd-amd64.iso"
}

variable "opnsense_cores" {
  description = "CPU cores for OPNsense (2 is sufficient, more helps with IDS/VPN)"
  type        = number
  default     = 2
}

variable "opnsense_memory" {
  description = "Memory in MB for OPNsense (2048 minimum, 4096 recommended with Suricata)"
  type        = number
  default     = 4096
}

variable "opnsense_disk_size" {
  description = "Disk size in GB for OPNsense"
  type        = number
  default     = 16
}

# WAN bridge -- must be a separate bridge connected to the ISP modem/ONT.
# Create vmbr1 on the Proxmox host and connect it to the physical NIC
# that goes to the modem. If using PCI passthrough, this bridge is unused
# (remove the WAN network_device block in vm-opnsense.tf).
variable "opnsense_wan_bridge" {
  description = "Proxmox bridge for WAN interface (connected to ISP modem)"
  type        = string
  default     = "vmbr1"
}

# LAN IP is configured inside OPNsense after install, not via Terraform.
# Default: 10.0.0.1 (becomes the network gateway for everything).
variable "opnsense_lan_ip" {
  description = "LAN IP for OPNsense (configured inside OPNsense, not Terraform)"
  type        = string
  default     = "10.0.0.1"
}
