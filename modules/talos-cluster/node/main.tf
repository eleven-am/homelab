locals {
  qemu_os    	   = "l26"
  cpu      	 	   = "x86-64-v4"
  os_type    	   = "cloud-init"
  scsihw     	   = "virtio-scsi-single"
  iso_storage_pool = "local"
  gateway    	   = cidrhost(var.subnet, 1)
  ip_address 	   = "${cidrhost(var.subnet, var.ip_offset)}/${var.cidr}"
}

resource "proxmox_vm_qemu" "node" {
  name         = var.node_name
  vmid         = var.vm_id
  target_node  = var.proxmox_node
  qemu_os      = local.qemu_os
  os_type 	   = local.os_type
  full_clone   = true

  onboot   = true
  tags     = var.tags
  clone    = var.template_name
  vm_state = "running"
  agent    = 0

  # Cloud-init
  cloudinit_cdrom_storage = "local-lvm"

  # System
  memory = var.node_memory
  cores  = var.node_cores
  cpu    = local.cpu
  scsihw = local.scsihw
  boot 	 = "order=scsi0"

  # Disk configuration
  disks {
	scsi {
	  scsi0 {
		disk {
		  storage = "local-lvm"
		  size 	  = var.node_disk_size
		}
	  }
	}
  }

  # Network configuration
  dynamic "network" {
	for_each = { for route in var.networks: route.tag => route }

	content {
	  model    = "virtio"
	  bridge   = network.value.bridge
	  firewall = network.value.firewall
	  tag 	   = network.value.tag
	}
  }

  ipconfig0 = "ip=${local.ip_address},gw=${local.gateway}"

  lifecycle {
	ignore_changes = [
	  boot,
	  network,
	  desc,
	  numa,
	  agent,
	  ipconfig0,
	  ipconfig1,
	  define_connection_info,
	]
  }
}


