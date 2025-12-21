locals {
  subnet_parts = split("/", var.subnet)
  subnet_cidr  = tonumber(local.subnet_parts[1])
  gateway      = var.gateway != "" ? var.gateway : cidrhost(var.subnet, 1)
  cluster_vip  = var.cluster_vip != "" ? var.cluster_vip : cidrhost(var.subnet, var.control_plane_ip_offset - 1)

  control_plane_ips = [
    for i in range(var.control_plane_count) :
    cidrhost(var.subnet, var.control_plane_ip_offset + i)
  ]

  worker_ips = [
    for i in range(var.worker_count) :
    cidrhost(var.subnet, var.worker_ip_offset + i)
  ]

  cluster_endpoint = "https://${local.cluster_vip}:6443"
  installer_image  = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version}"

  control_plane_actual_ips = [
    for vm in proxmox_virtual_environment_vm.control_plane :
    [for ip in flatten(vm.ipv4_addresses) : ip if ip != "127.0.0.1"][0]
  ]

  worker_actual_ips = [
    for vm in proxmox_virtual_environment_vm.worker :
    [for ip in flatten(vm.ipv4_addresses) : ip if ip != "127.0.0.1"][0]
  ]
}

resource "proxmox_virtual_environment_vm" "control_plane" {
  count = var.control_plane_count

  name        = "${var.cluster_name}-cp-${count.index}"
  description = "Talos ${var.talos_version} Control Plane Node ${count.index}"
  tags        = ["kubernetes", "talos", "control-plane"]
  node_name   = var.proxmox_node
  vm_id       = var.control_plane_vm_id_start + count.index
  on_boot     = true
  started     = true

  machine = "q35"
  bios    = "ovmf"

  cpu {
    cores   = var.control_plane_cores
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.control_plane_memory
  }

  efi_disk {
    datastore_id = var.proxmox_storage
    type         = "4m"
  }

  cdrom {
    enabled   = true
    file_id   = proxmox_virtual_environment_download_file.talos_image.id
    interface = "ide2"
  }

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = var.control_plane_disk_size
    file_format  = "raw"
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  scsi_hardware = "virtio-scsi-single"

  network_device {
    bridge  = var.network_bridge
    model   = "virtio"
    vlan_id = var.vlan_tag > 0 ? var.vlan_tag : null
  }

  dynamic "hostpci" {
    for_each = var.gpu_passthrough_enabled && var.gpu_mapping != "" ? [1] : []
    content {
      device  = "hostpci0"
      mapping = var.gpu_mapping
      pcie    = true
      rombar  = true
    }
  }

  initialization {
    datastore_id = var.proxmox_storage

    ip_config {
      ipv4 {
        address = "${local.control_plane_ips[count.index]}/${local.subnet_cidr}"
        gateway = local.gateway
      }
    }
  }

  agent {
    enabled = true
    timeout = "15m"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      cdrom,
      initialization,
    ]
  }

  depends_on = [proxmox_virtual_environment_download_file.talos_image]
}

resource "proxmox_virtual_environment_vm" "worker" {
  count = var.worker_count

  name        = "${var.cluster_name}-worker-${count.index}"
  description = "Talos ${var.talos_version} Worker Node ${count.index}"
  tags        = ["kubernetes", "talos", "worker"]
  node_name   = var.proxmox_node
  vm_id       = var.worker_vm_id_start + count.index
  on_boot     = true
  started     = true

  machine = "q35"
  bios    = "ovmf"

  cpu {
    cores   = var.worker_cores
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.worker_memory
  }

  efi_disk {
    datastore_id = var.proxmox_storage
    type         = "4m"
  }

  cdrom {
    enabled   = true
    file_id   = proxmox_virtual_environment_download_file.talos_image.id
    interface = "ide2"
  }

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = var.worker_disk_size
    file_format  = "raw"
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  scsi_hardware = "virtio-scsi-single"

  network_device {
    bridge  = var.network_bridge
    model   = "virtio"
    vlan_id = var.vlan_tag > 0 ? var.vlan_tag : null
  }

  initialization {
    datastore_id = var.proxmox_storage

    ip_config {
      ipv4 {
        address = "${local.worker_ips[count.index]}/${local.subnet_cidr}"
        gateway = local.gateway
      }
    }
  }

  dynamic "hostpci" {
    for_each = var.gpu_passthrough_enabled && var.gpu_mapping != "" ? [1] : []
    content {
      device  = "hostpci0"
      mapping = var.gpu_mapping
      pcie    = true
      rombar  = true
    }
  }

  agent {
    enabled = true
    timeout = "15m"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      cdrom,
      initialization,
    ]
  }

  depends_on = [proxmox_virtual_environment_download_file.talos_image]
}
