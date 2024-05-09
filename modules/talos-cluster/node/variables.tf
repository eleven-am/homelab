variable "node_name" {
  description = "Name of the node to be created"
  type 	  	  = string
}

variable "vm_id" {
  description = "The ID of the VM to be created on the Proxmox node"
  type 	  	  = number
}

variable "proxmox_node" {
  description = "The Proxmox node to create the VM on"
  type 	  	  = string
}

variable "tags" {
  description = "Tags to be applied to the VM"
  type 	  	  = string
}

variable "template_name" {
  description = "The name of the template to create the VM from"
  type 	  	  = string
}

variable "node_memory" {
  description = "Amount of memory to allocate to the VM"
  type 	  	  = number
}

variable "node_disk_size" {
  description = "Size of the disk to allocate to the VM"
  type 	  	  = number
}

variable "node_cores" {
  description = "Number of cores to allocate to the VM"
  type 	  	  = number
}

variable "subnet" {
  description = "The subnet to connect the VM to"
  type 	  	  = string
}

variable "cidr" {
  description = "The CIDR of the subnet"
  type 	  	  = number
}

variable "ip_offset" {
  description = "The offset of the IP address to assign to the VM"
  type 	  	  = number
}

variable "networks" {
  description = "The networks to connect the VM to"
  type 	  	  = list(object({
	bridge   = string
	firewall = bool
	tag      = number
  }))
}
