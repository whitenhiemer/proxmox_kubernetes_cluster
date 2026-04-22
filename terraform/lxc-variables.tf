# lxc-variables.tf - Variables for LXC container provisioning

# --- LXC Storage ---
# LXC containers use local storage (faster, no Ceph overhead for lightweight services)
variable "lxc_storage" {
  description = "Proxmox storage for LXC container disks"
  type        = string
  default     = "local-lvm"
}

variable "debian_template" {
  description = "Debian LXC template file ID (e.g., local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}

# --- SSH Key ---
variable "ssh_public_key" {
  description = "SSH public key to inject into LXC containers for Ansible access"
  type        = string
  default     = ""
}

# --- Traefik LXC ---
variable "traefik_vmid" {
  description = "VM ID for the Traefik reverse proxy LXC"
  type        = number
  default     = 200
}

variable "traefik_ip" {
  description = "Static IP for the Traefik LXC"
  type        = string
  default     = "10.0.0.20"
}

# --- Recipe Site LXC ---
variable "recipe_site_vmid" {
  description = "VM ID for the recipe site LXC"
  type        = number
  default     = 201
}

variable "recipe_site_ip" {
  description = "Static IP for the recipe site LXC"
  type        = string
  default     = "10.0.0.21"
}

# --- ARR Stack LXC ---
variable "arr_vmid" {
  description = "VM ID for the ARR media management stack LXC"
  type        = number
  default     = 202
}

variable "arr_ip" {
  description = "Static IP for the ARR stack LXC"
  type        = string
  default     = "10.0.0.22"
}

variable "arr_cores" {
  description = "CPU cores for the ARR stack (runs multiple Docker containers)"
  type        = number
  default     = 2
}

variable "arr_memory" {
  description = "Memory in MB for the ARR stack"
  type        = number
  default     = 4096
}

variable "arr_disk_size" {
  description = "Disk size in GB for the ARR stack (configs + temp downloads, media on NAS)"
  type        = number
  default     = 20
}

# --- Domain ---
variable "domain" {
  description = "Base domain name for services"
  type        = string
  default     = "woodhead.tech"
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME registration"
  type        = string
  default     = ""
}
