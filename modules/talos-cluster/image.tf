locals {
  base_extensions = [
    "siderolabs/qemu-guest-agent",
    "siderolabs/amd-ucode",
  ]

  nvidia_extensions = var.enable_nvidia_gpu ? [
    "siderolabs/nonfree-kmod-nvidia-production",
    "siderolabs/nvidia-container-toolkit-production",
  ] : []

  all_extensions = concat(
    local.base_extensions,
    local.nvidia_extensions,
    var.extra_extensions
  )
}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = local.all_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
      }
    }
  })
}

resource "proxmox_virtual_environment_download_file" "talos_image" {
  node_name    = var.proxmox_node
  content_type = "iso"
  datastore_id = var.iso_storage

  url       = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.iso"
  file_name = "talos-${var.talos_version}-${substr(talos_image_factory_schematic.this.id, 0, 8)}.iso"

  overwrite_unmanaged = true
}

output "schematic_id" {
  description = "The Talos Image Factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "extensions_included" {
  description = "Extensions included in the image"
  value       = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
}

output "image_url" {
  description = "The Talos image URL"
  value       = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.iso"
}
