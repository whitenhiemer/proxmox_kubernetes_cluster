# vm-truenas-variables.tf - Variables for the TrueNAS Scale NAS VM

variable "truenas_vmid" {
  description = "VM ID for the TrueNAS NAS"
  type        = number
  default     = 300
}

variable "truenas_iso" {
  description = "Path to TrueNAS Scale ISO on Proxmox storage (e.g., local:iso/TrueNAS-SCALE.iso)"
  type        = string
  default     = "local:iso/TrueNAS-SCALE.iso"
}

variable "truenas_cores" {
  description = "CPU cores for TrueNAS (2 minimum, 4 recommended for scrubs + NFS serving)"
  type        = number
  default     = 4
}

variable "truenas_memory" {
  description = "Memory in MB for TrueNAS (8192 minimum, ZFS ARC uses ~1GB per TB of storage)"
  type        = number
  default     = 8192
}

variable "truenas_disk_size" {
  description = "OS disk size in GB for TrueNAS (data goes on passthrough disks, not here)"
  type        = number
  default     = 16
}

variable "truenas_ip" {
  description = "Static IP for TrueNAS (configured inside TrueNAS, not via Terraform)"
  type        = string
  default     = "192.168.86.40"
}
