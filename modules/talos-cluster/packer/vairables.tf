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

