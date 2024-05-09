variable "proxmox_host" {
  description = "The Proxmox host URL to connect to"
  type        = string
}

variable "proxmox_username" {
  description = "The Proxmox username to authenticate with"
  type        = string
}

variable "proxmox_token" {
  description = "The Proxmox token to authenticate with"
  type        = string
}

variable "proxmox_node" {
  description = "The Proxmox node to create the VM template on"
  type        = string
}

variable "proxmox_storage" {
  description = "The Proxmox storage pool to create the VM template on"
  type        = string
}

variable "proxmox_storage_type" {
  description = "The Proxmox storage pool type to create the VM template on"
  type        = string
}

variable "iso_url" {
  description = "The URL to the Talos ISO to use"
  type        = string
}

variable "iso_checksum" {
  description = "The checksum of the Talos ISO"
  type        = string
}

variable "iso_storage_pool" {
  description = "The Proxmox storage pool to store the Talos ISO"
  type        = string
}

variable "talos_version" {
  description = "The version of Talos to use"
  type        = string
}

variable "schematic_id" {
  description = "The schematic ID to use for the installation of talos"
  type        = string
}

variable cidr {
  description = "The CIDR block for the cluster"
  type        = number
}

variable cluster_prefix {
  description = "The prefix for the cluster"
  type        = string
}

variable ip_offset {
  description = "The offset for the IP addresses"
  type        = number
}

variable master_count {
  description = "The number of Kubernetes master nodes"
  type        = number
}

variable worker_count {
  description = "The number of Kubernetes worker nodes"
  type        = number
}

variable master_cores {
  description = "The number of cores for the master nodes"
  type        = number
}

variable master_memory {
  description = "The amount of memory for the master nodes"
  type        = number
}

variable master_network_bridge {
  description = "The network bridge for the master nodes"
  type        = string
}

variable master_vlan_tag {
  description = "The VLAN tag for the master nodes"
  type        = number
}

variable "master_disk_size" {
  description = "Disk size for master nodes"
  type 	  	  = number
}

variable subnet {
  description = "The subnet for the cluster"
  type        = string
}

variable worker_cores {
  description = "The number of cores for the worker nodes"
  type        = number
}

variable worker_memory {
  description = "The amount of memory for the worker nodes"
  type        = number
}

variable worker_network_bridge {
  description = "The network bridge for the worker nodes"
  type        = string
}

variable worker_vlan_tag {
  description = "The VLAN tag for the worker nodes"
  type        = number
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes"
  type 	  	  = number
}
