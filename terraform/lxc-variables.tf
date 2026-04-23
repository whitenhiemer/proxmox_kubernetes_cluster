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

# --- Node Assignments ---
# Distribute LXC containers across Proxmox cluster nodes.
# Keys must match the container names used in each lxc-*.tf file.
variable "node_assignments" {
  description = "Map of container name to Proxmox node for multi-node distribution"
  type        = map(string)
  default     = {}
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

# --- Plex LXC ---
variable "plex_vmid" {
  description = "VM ID for the Plex Media Server LXC"
  type        = number
  default     = 203
}

variable "plex_ip" {
  description = "Static IP for the Plex LXC"
  type        = string
  default     = "10.0.0.23"
}

variable "plex_cores" {
  description = "CPU cores for Plex (iGPU handles transcoding, CPU for metadata/scanning)"
  type        = number
  default     = 2
}

variable "plex_memory" {
  description = "Memory in MB for Plex"
  type        = number
  default     = 2048
}

variable "plex_disk_size" {
  description = "Disk size in GB for Plex (metadata + thumbnails, media on NAS)"
  type        = number
  default     = 8
}

# --- Jellyfin LXC ---
variable "jellyfin_vmid" {
  description = "VM ID for the Jellyfin Media Server LXC"
  type        = number
  default     = 204
}

variable "jellyfin_ip" {
  description = "Static IP for the Jellyfin LXC"
  type        = string
  default     = "10.0.0.24"
}

variable "jellyfin_cores" {
  description = "CPU cores for Jellyfin (iGPU handles transcoding)"
  type        = number
  default     = 2
}

variable "jellyfin_memory" {
  description = "Memory in MB for Jellyfin"
  type        = number
  default     = 2048
}

variable "jellyfin_disk_size" {
  description = "Disk size in GB for Jellyfin (metadata + cache, media on NAS)"
  type        = number
  default     = 8
}

# --- Monitoring Stack LXC ---
variable "monitoring_vmid" {
  description = "VM ID for the monitoring stack LXC (Prometheus, Grafana, Alertmanager)"
  type        = number
  default     = 205
}

variable "monitoring_ip" {
  description = "Static IP for the monitoring stack LXC"
  type        = string
  default     = "10.0.0.25"
}

variable "monitoring_cores" {
  description = "CPU cores for the monitoring stack (Prometheus query engine + Grafana rendering)"
  type        = number
  default     = 2
}

variable "monitoring_memory" {
  description = "Memory in MB for the monitoring stack (Prometheus TSDB + Grafana + exporters)"
  type        = number
  default     = 2048
}

variable "monitoring_disk_size" {
  description = "Disk size in GB for the monitoring stack (Prometheus TSDB, 30-day retention)"
  type        = number
  default     = 20
}

# --- OpenClaw LXC ---
variable "openclaw_vmid" {
  description = "VM ID for the OpenClaw AI agent framework LXC"
  type        = number
  default     = 206
}

variable "openclaw_ip" {
  description = "Static IP for the OpenClaw LXC"
  type        = string
  default     = "10.0.0.26"
}

variable "openclaw_cores" {
  description = "CPU cores for OpenClaw (Node.js gateway + CLI)"
  type        = number
  default     = 2
}

variable "openclaw_memory" {
  description = "Memory in MB for OpenClaw (Node.js runtime + LLM API calls)"
  type        = number
  default     = 2048
}

variable "openclaw_disk_size" {
  description = "Disk size in GB for OpenClaw (source build + Docker images + workspace)"
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
