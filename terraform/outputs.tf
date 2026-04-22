# outputs.tf - Useful outputs after VM creation

output "controlplane_vm_ids" {
  description = "VM IDs of control plane nodes"
  value       = proxmox_virtual_environment_vm.controlplane[*].vm_id
}

output "controlplane_names" {
  description = "Names of control plane nodes"
  value       = proxmox_virtual_environment_vm.controlplane[*].name
}

output "worker_vm_ids" {
  description = "VM IDs of worker nodes"
  value       = proxmox_virtual_environment_vm.worker[*].vm_id
}

output "worker_names" {
  description = "Names of worker nodes"
  value       = proxmox_virtual_environment_vm.worker[*].name
}

output "controlplane_ips" {
  description = "Control plane node IPs (from variables)"
  value       = var.controlplane_ips
}

output "worker_ips" {
  description = "Worker node IPs (from variables)"
  value       = var.worker_ips
}

output "cluster_vip" {
  description = "Kubernetes API VIP"
  value       = var.cluster_vip
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint URL"
  value       = "https://${var.cluster_vip}:6443"
}

# --- LXC Outputs ---

output "traefik_ip" {
  description = "Traefik reverse proxy LXC IP"
  value       = var.traefik_ip
}

output "traefik_vmid" {
  description = "Traefik LXC VM ID"
  value       = proxmox_virtual_environment_container.traefik.vm_id
}

output "recipe_site_ip" {
  description = "Recipe site LXC IP"
  value       = var.recipe_site_ip
}

output "recipe_site_vmid" {
  description = "Recipe site LXC VM ID"
  value       = proxmox_virtual_environment_container.recipe_site.vm_id
}

output "domain" {
  description = "Base domain for services"
  value       = var.domain
}

# --- OPNsense Outputs ---

output "opnsense_vmid" {
  description = "OPNsense firewall VM ID"
  value       = proxmox_virtual_environment_vm.opnsense.vm_id
}

output "opnsense_lan_ip" {
  description = "OPNsense LAN gateway IP (configured inside OPNsense)"
  value       = var.opnsense_lan_ip
}
