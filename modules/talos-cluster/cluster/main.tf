locals {
  kube_tag   	   = "kubernetes"
  master_tag 	   = "master"
  worker_tag 	   = "worker"
  talos_tag 	   = "talos"
  cluster_name     = "${var.cluster_prefix}-cluster"
  cluster_ip 	   = cidrhost(var.subnet, var.ip_offset - 1)
  primary_ip 	   = cidrhost(var.subnet, var.ip_offset)
  cluster_endpoint = "https://${local.cluster_ip}:6443"
  primary_endpoint = "https://${local.primary_ip}:6443"
  installer 	   = "factory.talos.dev/installer/${var.schematic_id}:${var.talos_version}"
}

module "kubernetes-masters" {
  source = "../node"

  count  = var.master_count

  cidr   		 = var.cidr
  ip_offset 	 = var.ip_offset + count.index
  node_cores     = var.master_cores
  node_memory    = var.master_memory
  node_name      = "${var.cluster_prefix}-${local.master_tag}-${count.index}"
  proxmox_node   = var.proxmox_node
  subnet 		 = var.subnet
  tags   		 = "${local.kube_tag};${local.master_tag};${local.talos_tag}"
  template_name  = var.template_name
  vm_id  		 = 600 + count.index
  node_disk_size = var.master_disk_size

  networks = [
	{
	  bridge   = var.master_network_bridge
	  tag      = var.master_vlan_tag
	  firewall = false
	}
  ]
}

module "kubernetes-workers" {
  source = "../node"

  count  = var.worker_count

  cidr   		 = var.cidr
  ip_offset 	 = count.index + var.master_count + var.ip_offset
  node_cores     = var.worker_cores
  node_memory    = var.worker_memory
  node_name      = "${var.cluster_prefix}-${local.worker_tag}-${count.index}"
  proxmox_node   = var.proxmox_node
  subnet 		 = var.subnet
  tags   		 = "${local.kube_tag};${local.worker_tag};${local.talos_tag}"
  template_name  = var.template_name
  vm_id  		 = 700 + count.index
  node_disk_size = var.worker_disk_size

  networks = [
	{
	  bridge   = var.worker_network_bridge
	  tag      = var.worker_vlan_tag
	  firewall = false
	}
  ]
}

locals {
  master_node_ips = [for instance in module.kubernetes-masters : instance.node_ip]
  master_node_names = [for instance in module.kubernetes-masters : instance.node_name]
  worker_node_ips = [for instance in module.kubernetes-workers : instance.node_ip]
  worker_node_names = [for instance in module.kubernetes-workers : instance.node_name]
}

# Create the machine configuration
resource "null_resource" "machine_config" {
  count = length(module.kubernetes-masters) > 0 ? 1 : 0

  triggers = {
	kubernetes_master_ips = join(",", module.kubernetes-masters.*.node_ip)
	kubernetes_worker_ips = join(",", module.kubernetes-workers.*.node_ip)
  }

  # remove and recreate the talos directory
  provisioner "local-exec" {
	command = "rm -rf ${var.talos_directory} && mkdir -p ${var.talos_directory}"
  }

  # generate the talos configuration
  provisioner "local-exec" {
	command = "talosctl gen config ${local.cluster_name} ${local.primary_endpoint} --output-dir ${var.talos_directory}"
  }

  # sleep for a few seconds to allow the talosctl command to complete
  provisioner "local-exec" {
	command = "sleep 20"
  }
}

# Create the control panel patch files
resource "local_file" "control_plane_patch" {
  depends_on = [null_resource.machine_config]
  count      = length(module.kubernetes-masters)

  content =	yamlencode({
	machine = {
	  network = {
		nameservers = ["1.1.1.1", "8.8.8.8"]
		hostname = local.master_node_names[count.index]
		interfaces = [
		  {
			vip = {
			  ip = local.cluster_ip
			}
			addresses = ["${local.master_node_ips[count.index]}/24"]
			deviceSelector = {
			  physical = true
			}
		  }
		]
	  }
	  features = {
		kubePrism = {
		  enabled = true
		  port	= 7445
		}
		kubernetesTalosAPIAccess = {
		  enabled = true
		  allowedRoles = ["os:reader"]
		  allowedKubernetesNamespaces = ["kube-system"]
		}
	  }
	  install = {
		image = local.installer
	  }
	}
	cluster = {
	  allowSchedulingOnControlPlanes = true
	}
  })

  filename = "${var.talos_directory}/${module.kubernetes-masters[count.index].node_name}.yaml"
}

# Create the worker patch files
resource "local_file" "worker_patch" {
  depends_on = [null_resource.machine_config]
  count      = length(module.kubernetes-workers)

  content =	yamlencode({
	machine = {
	  network = {
		nameservers = ["1.1.1.1", "8.8.8.8"]
		hostname = local.worker_node_names[count.index]
		interfaces = [
		  {
			addresses = ["${local.worker_node_ips[count.index]}/24"]
			deviceSelector = {
			  physical = true
			}
		  }
		]
	  }
	  features = {
		kubePrism = {
		  enabled = true
		  port    = 7445
		}
	  }
	  install = {
		image = local.installer
	  }
	}
  })

  filename = "${var.talos_directory}/${module.kubernetes-workers[count.index].node_name}.yaml"
}

# Apply the machine configuration to the control plane
resource "null_resource" "apply_machine_config" {
  depends_on = [null_resource.machine_config]
  count      = length(module.kubernetes-masters)

  triggers = {
	kubernetes_master_ips = join(",", module.kubernetes-masters.*.node_ip)
  }

  # apply the machine configuration to the control plane
  provisioner "local-exec" {
	command = "talosctl apply-config --insecure --nodes ${module.kubernetes-masters[count.index].node_ip} --file ${var.talos_directory}/controlplane.yaml --config-patch @${var.talos_directory}/${module.kubernetes-masters[count.index].node_name}.yaml"
  }

  # sleep for a few seconds to allow the talosctl command to complete
  provisioner "local-exec" {
	command = "sleep 5"
  }

  # delete the patch file
  provisioner "local-exec" {
	command = "rm -f ${var.talos_directory}/${module.kubernetes-masters[count.index].node_name}.yaml"
  }
}

# Apply the machine configuration to the workers
resource "null_resource" "apply_worker_config" {
  depends_on = [null_resource.machine_config]
  count      = length(module.kubernetes-workers)

  triggers = {
	kubernetes_worker_ips = join(",", module.kubernetes-workers.*.node_ip)
  }

  # apply the machine configuration to the workers
  provisioner "local-exec" {
	command = "talosctl apply-config --insecure --nodes ${module.kubernetes-workers[count.index].node_ip} --file ${var.talos_directory}/worker.yaml --config-patch @${var.talos_directory}/${module.kubernetes-workers[count.index].node_name}.yaml"
  }

  # sleep for a few seconds to allow the talosctl command to complete
  provisioner "local-exec" {
	command = "sleep 5"
  }

  # delete the patch file
  provisioner "local-exec" {
	command = "rm -f ${var.talos_directory}/${module.kubernetes-workers[count.index].node_name}.yaml"
  }
}

# Bootstrap the cluster
resource "null_resource" "bootstrap" {
  depends_on = [null_resource.apply_machine_config, null_resource.apply_worker_config]
  count      = length(module.kubernetes-masters) > 0 ? 1 : 0

  # sleep for 45 seconds to allow the machine configuration to complete
  provisioner "local-exec" {
	command = "sleep 45"
  }

  # bootstrap the cluster
  provisioner "local-exec" {
	command = "talosctl bootstrap --nodes ${module.kubernetes-masters[0].node_ip} -e ${module.kubernetes-masters[0].node_ip} --talosconfig=${var.talos_directory}/talosconfig"
  }

  # wait another 45 seconds for the bootstrap to complete
  provisioner "local-exec" {
	command = "sleep 45"
  }
}

# Health check the cluster
resource "null_resource" "health_check" {
  depends_on = [null_resource.bootstrap]
  count      = length(module.kubernetes-masters) > 0 ? 1 : 0

  provisioner "local-exec" {
	command = "${path.root}/scripts/health_check_and_configure.sh -p ${module.kubernetes-masters[0].node_ip} -t ${var.talos_directory}"
  }
}
