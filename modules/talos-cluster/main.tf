
module "talos_image" {
  source = "./packer"

  iso_checksum 		   = var.iso_checksum
  iso_storage_pool 	   = var.iso_storage_pool
  iso_url 			   = var.iso_url
  proxmox_host 		   = var.proxmox_host
  proxmox_node 		   = var.proxmox_node
  proxmox_storage 	   = var.proxmox_storage
  proxmox_storage_type = var.proxmox_storage_type
  proxmox_token 	   = var.proxmox_token
  proxmox_username     = var.proxmox_username
  talos_version        = var.talos_version
  schematic_id         = var.schematic_id
}

module "talos_cluster" {
  depends_on = [module.talos_image]

  source = "./cluster"

  cidr                    = var.cidr
  cluster_prefix          = var.cluster_prefix
  master_ip_offset        = var.master_ip_offset
  master_count 			  = var.master_count
  worker_count 			  = var.worker_count
  master_cores            = var.master_cores
  master_memory           = var.master_memory
  master_network_bridge   = var.master_network_bridge
  master_vlan_tag         = var.master_vlan_tag
  proxmox_node            = var.proxmox_node
  subnet                  = var.subnet
  template_name           = module.talos_image.template_name
  worker_ip_offset        = var.worker_ip_offset
  worker_cores            = var.worker_cores
  worker_memory           = var.worker_memory
  worker_network_bridge   = var.worker_network_bridge
  worker_vlan_tag         = var.worker_vlan_tag
  talos_version           = var.talos_version
  schematic_id            = var.schematic_id
  master_disk_size        = var.master_disk_size
  worker_disk_size        = var.worker_disk_size
  github_repository       = var.github_repository
  github_token            = var.github_token
  github_username         = var.github_username
  sops_age_key            = var.sops_age_key
}
