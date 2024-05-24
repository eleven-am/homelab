variable "cluster_prefix" {
  description = "Prefix for the cluster name"
  type 	  	  = string
}

variable "cidr" {
  description = "CIDR for the cluster"
  type 	  	  = number
}

variable "subnet" {
  description = "Subnet for the cluster"
  type 	  	  = string
}

variable "proxmox_node" {
  description = "Name of the Proxmox node"
  type 	  	  = string
}

variable "template_name" {
  description = "Name of the template to use for the VMs"
  type 	  	  = string
}

variable "talos_version" {
  description = "The version of Talos to use"
  type        = string
}

variable "talos_directory" {
  description = "Directory to store the talos config"
  type        = string
  default     = "talos"
}

variable "schematic_id" {
  description = "The schematic ID to use for the installation of talos"
  type        = string
}

variable "master_count" {
  description = "Number of Kubernetes master nodes"
  type 	  	  = number
}

variable "master_cores" {
  description = "Number of cores for master nodes"
  type 	  	  = number
}

variable "master_memory" {
  description = "Memory for master nodes"
  type 	  	  = number
}

variable "master_disk_size" {
  description = "Disk size for master nodes"
  type 	  	  = number
}

variable "master_network_bridge" {
  description = "Name of the bridge for the master network"
  type 	  	  = string
}

variable "master_ip_offset" {
  description = "Offset for the IP addresses for the master nodes"
  type 	  	  = number
}

variable "master_vlan_tag" {
  description = "VLAN tag for the master network"
  type 	  	  = number
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  type 	  	  = number
}

variable "worker_cores" {
  description = "Number of cores for worker nodes"
  type 	  	  = number
}

variable "worker_memory" {
  description = "Memory for worker nodes"
  type 	  	  = number
}

variable "worker_network_bridge" {
  description = "Name of the bridge for the worker network"
  type 	  	  = string
}

variable "worker_ip_offset" {
  description = "Offset for the IP addresses for the worker nodes"
  type 	  	  = number
}

variable "worker_vlan_tag" {
  description = "VLAN tag for the worker network"
  type 	  	  = number
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes"
  type 	  	  = number
}

variable "github_username" {
  description = "Github username to use for the installation of flux"
  type        = string
}

variable "github_token" {
  description = "Github token to use for the installation of flux"
  type        = string
}

variable "github_repository" {
  description = "Github repository to use for the installation of flux"
  type        = string
}

variable "sops_age_key" {
  description = "Age key to use for the installation of sops"
  type        = string
}
