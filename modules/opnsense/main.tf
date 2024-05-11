locals {
  qemu_os    	   = "l26"
  os_type    	   = "cloud-init"
  ubuntu_tag 	   = "ubuntu"
  opnsense_tag 	   = "opnsense"
  desktop_tag 	   = "desktop"
  router_tag 	   = "router"
  cpu      	 	   = "x86-64-v4"
  scsihw     	   = "virtio-scsi-single"
  iso_storage_pool = "local"
  node_disk_size   = 20
  model            = "virtio"
  firewall         = "1"
  LAN_bridge       = "LAN"
  WAN_bridge       = "WAN"
  ubuntu_iso       = "local:iso/ubuntu-22.04.4-desktop-amd64.iso"
  opnsense_iso     = "local:iso/OPNsense-24.1-dvd-amd64.iso"
  opnsense_id      = 8000
  proxmox_node     = "horus"
}

# Create a new VM for Ubuntu Desktop
resource "proxmox_vm_qemu" "ubuntu_desktop" {
  name 			= "${local.ubuntu_tag}-${local.desktop_tag}"
  vmid 			= local.opnsense_id + 1
  target_node   = local.proxmox_node
  qemu_os 		= local.qemu_os
  os_type 		= local.os_type

  onboot 		= true
  iso 			= local.ubuntu_iso
  tags 			= "${local.ubuntu_tag};${local.desktop_tag}"

  # System
  memory 		= 2048
  cores 		= 4
  cpu 			= local.cpu
  scsihw 		= local.scsihw

  # Disk configuration
  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size 	  = local.node_disk_size
        }
      }
    }
  }

  # Network configuration
  network {
    model    = local.model
    bridge   = local.LAN_bridge
    firewall = local.firewall
  }
}

# Create a new VM for OPNsense Router
resource "proxmox_vm_qemu" "opnsense_router" {
  name 			= "${local.opnsense_tag}-${local.router_tag}"
  vmid 			= local.opnsense_id
  target_node   = local.proxmox_node
  qemu_os 		= local.qemu_os
  os_type 		= local.os_type

  onboot 		= true
  iso 			= local.opnsense_iso
  tags 			= "${local.opnsense_tag};${local.router_tag}"

  # System
  memory 		= 4096
  cores 		= 4
  cpu 			= local.cpu
  scsihw 		= local.scsihw

  # Disk configuration
  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size 	  = local.node_disk_size
        }
      }
    }
  }

  # Network configuration
  network {
    model    = local.model
    bridge   = local.WAN_bridge
    firewall = local.firewall
  }

  network {
    model    = local.model
    bridge   = local.LAN_bridge
    firewall = local.firewall
  }
}
