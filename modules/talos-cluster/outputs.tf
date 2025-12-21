output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = local.cluster_endpoint
}

output "cluster_vip" {
  description = "Virtual IP for the cluster"
  value       = local.cluster_vip
}

output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value       = local.control_plane_ips
}

output "control_plane_names" {
  description = "Names of control plane VMs"
  value       = [for vm in proxmox_virtual_environment_vm.control_plane : vm.name]
}

output "worker_ips" {
  description = "IP addresses of worker nodes"
  value       = local.worker_ips
}

output "worker_names" {
  description = "Names of worker VMs"
  value       = [for vm in proxmox_virtual_environment_vm.worker : vm.name]
}

output "talos_version" {
  description = "Talos Linux version deployed"
  value       = var.talos_version
}

output "talosconfig_path" {
  description = "Path to the talosconfig file"
  value       = var.control_plane_count > 0 ? local_file.talosconfig[0].filename : null
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = var.control_plane_count > 0 ? local_file.kubeconfig[0].filename : null
}

output "talos_schematic_id" {
  description = "Talos Image Factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "talos_installer_image" {
  description = "Talos installer image URL"
  value       = local.installer_image
}

output "talos_extensions" {
  description = "Extensions included in the Talos image"
  value       = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
}

output "nvidia_gpu_enabled" {
  description = "Whether NVIDIA GPU support is enabled"
  value       = var.enable_nvidia_gpu
}

output "gpu_passthrough_enabled" {
  description = "Whether GPU passthrough is enabled for workers"
  value       = var.gpu_passthrough_enabled
}
