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

variable "talos_iso_url" {
  description = "The URL to the Talos raw image to use"
  type        = string
}

variable "talos_template_name" {
  description = "The name of the Talos template to create"
  type        = string
}

variable "talos_template_description" {
  description = "The description of the Talos template to create"
  type        = string
}
