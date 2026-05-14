# vm-homeassistant-variables.tf - Variables for the Home Assistant OS VM

variable "homeassistant_vmid" {
  description = "VM ID for the Home Assistant VM"
  type        = number
  default     = 301
}

# HAOS disk image URL -- update the version as new releases come out.
# Check https://www.home-assistant.io/installation/alternative for the latest.
# Use the "qcow2.xz" variant for Proxmox (KVM/QEMU).
variable "homeassistant_image_url" {
  description = "URL to HAOS qcow2.xz disk image (Proxmox/KVM variant)"
  type        = string
  default     = "https://github.com/home-assistant/operating-system/releases/download/14.2/haos_ova-14.2.qcow2.xz"
}

variable "homeassistant_cores" {
  description = "CPU cores for Home Assistant (2 is sufficient for most setups)"
  type        = number
  default     = 2
}

variable "homeassistant_memory" {
  description = "Memory in MB for Home Assistant (2048 minimum, more for many addons)"
  type        = number
  default     = 2048
}

variable "homeassistant_balloon" {
  description = "Minimum guaranteed RAM in MB for Home Assistant (balloon floor)"
  type        = number
  default     = 1024
}

variable "homeassistant_disk_size" {
  description = "Disk size in GB for Home Assistant (HAOS + addons + database)"
  type        = number
  default     = 32
}

variable "homeassistant_iops_read" {
  description = "IOPS read limit for Home Assistant"
  type        = number
  default     = 1000
}

variable "homeassistant_iops_write" {
  description = "IOPS write limit for Home Assistant"
  type        = number
  default     = 1000
}

variable "homeassistant_ip" {
  description = "Static IP for Home Assistant (configured inside HAOS, not via Terraform)"
  type        = string
  default     = "192.168.86.41"
}
