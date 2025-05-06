packer {
  required_plugins {
    name = {
      version = ">= 1.1.7"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

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

variable "vm_id" {
  description = "The VM ID to use"
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

source "proxmox-iso" "talos-template" {
  # Proxmox connection details
  proxmox_url              = var.proxmox_host
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # Base ISO configuration
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  iso_storage_pool = var.iso_storage_pool
  unmount_iso      = true

  # VM configuration
  scsi_controller = "virtio-scsi-pci"
  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Disk configuration
  disks {
    type              = "scsi"
    storage_pool      = var.proxmox_storage
    storage_pool_type = var.proxmox_storage_type
    format            = "raw"
    disk_size         = "4500M"
    cache_mode        = "writethrough"
  }

  memory                  = 2048
  cores                   = 4
  cpu_type                = "x86-64-v4"

  ssh_username            = "root"
  ssh_password            = "packer"
  ssh_timeout             = "15m"
  qemu_agent              = true
  cloud_init              = true
  vm_id                   = var.vm_id
  tags                    = "talos;template"
  cloud_init_storage_pool = var.proxmox_storage

  template_name        = var.talos_template_name
  template_description = var.talos_template_description

  boot_wait = "25s"
  boot_command = [
    "<enter><wait1m>",
    "passwd<enter><wait>packer<enter><wait>packer<enter>",
  ]
}

build {
  name    = "release"
  sources = ["source.proxmox-iso.talos-template"]

  provisioner "shell" {
    inline = [
      "curl -L ${var.talos_iso_url} -o /tmp/talos.raw.xz",
      "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync",
    ]
  }
}
