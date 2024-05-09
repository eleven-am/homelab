locals {
  vm_id 		= "8000"
  template_name = "talos-${var.talos_version}"
  talos_iso_url = "https://factory.talos.dev/image/${var.schematic_id}/${var.talos_version}/nocloud-amd64.raw.xz"
}

resource "local_file" "values_pkr_json" {
  filename = "${path.module}/values.pkr.json"

  content = jsonencode({
	proxmox_host               = var.proxmox_host
	proxmox_username           = var.proxmox_username
	proxmox_token              = var.proxmox_token
	proxmox_node               = var.proxmox_node
	proxmox_storage            = var.proxmox_storage
	proxmox_storage_type       = var.proxmox_storage_type
	iso_url                    = var.iso_url
	vm_id					   = local.vm_id
	iso_checksum               = var.iso_checksum
	iso_storage_pool           = var.iso_storage_pool
	talos_iso_url              = local.talos_iso_url
	talos_template_name        = local.template_name
	talos_template_description = "A Talos ${var.talos_version} built on Arch Linux with QEMU"
  })
}

resource "null_resource" "packer_build" {
  depends_on = [local_file.values_pkr_json]

  triggers = {
	talos_iso_url = local.talos_iso_url
	iso_url       = var.iso_url
  }

  provisioner "local-exec" {
	command = "packer build -var-file=${local_file.values_pkr_json.filename} ${path.module}/packer.pkr.hcl"
  }
}

resource "null_resource" "cleanup" {
  depends_on = [null_resource.packer_build]

  triggers = {
	talos_iso_url = local.talos_iso_url
	iso_url       = var.iso_url
  }

  provisioner "local-exec" {
	command = "rm -rf ${path.module}/values.pkr.json"
  }
}

resource "null_resource" "sleep_30" {
  depends_on = [null_resource.packer_build]

  provisioner "local-exec" {
	command = "sleep 30"
  }
}

