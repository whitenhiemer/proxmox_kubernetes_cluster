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
