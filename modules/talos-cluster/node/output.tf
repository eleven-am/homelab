output "node_name" {
  value       = proxmox_vm_qemu.node.name
  description = "Name of the node"
}

output "node_id" {
  value       = proxmox_vm_qemu.node.id
  description = "ID of the node"
}

output "node_ip" {
  value       = cidrhost(var.subnet, var.ip_offset)
  description = "IP of the node"
}
