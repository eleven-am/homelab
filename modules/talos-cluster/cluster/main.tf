locals {
  kube_tag   	   = "kubernetes"
  master_tag 	   = "master"
  worker_tag 	   = "worker"
  talos_tag 	   = "talos"
  cluster_name     = "${var.cluster_prefix}-cluster"
  cluster_ip 	   = cidrhost(var.subnet, var.master_ip_offset - 1)
  primary_ip 	   = cidrhost(var.subnet, var.master_ip_offset)
  cluster_endpoint = "https://${local.cluster_ip}:6443"
  primary_endpoint = "https://${local.primary_ip}:6443"
  installer 	   = "factory.talos.dev/installer/${var.schematic_id}:${var.talos_version}"
}

module "kubernetes-masters" {
  source = "../node"

  count  = var.master_count

  cidr   		 = var.cidr
  ip_offset 	 = var.master_ip_offset + count.index
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
  ip_offset 	 = var.worker_ip_offset + count.index
  node_cores     = var.worker_cores
  node_memory    = var.worker_memory
  node_name      = "${var.cluster_prefix}-${local.worker_tag}-${count.index}"
  proxmox_node   = var.proxmox_node
  subnet 		 = var.subnet
  tags   		 = "${local.kube_tag};${local.talos_tag};${local.worker_tag}"
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

data "helm_template" "cilium_template" {
  name       = "cilium"
  namespace  = "kube-system"
  version    = "1.15.5"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }

  set {
      name  = "kubeProxyReplacement"
      value = "true"
  }

  set {
      name  = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
  }

  set {
      name  = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
  }

  set {
      name  = "cgroup.autoMount.enabled"
      value = "false"
  }

  set {
      name  = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
  }

  set {
      name  = "prometheus.enabled"
      value = "true"
  }

  set {
      name  = "k8sServiceHost"
      value = "localhost"
  }

  set {
      name  = "hubble.metrics.enabled"
      value = "{dns,drop,tcp,flow,icmp,http}"
  }

  set {
      name  = "hubble.relay.enabled"
      value = "true"
  }

  set {
      name  = "hubble.ui.enabled"
      value = "true"
  }

  set {
      name  = "gatewayAPI.enabled"
      value = "true"
  }

  set {
      name  = "bgpControlPlane.enabled"
      value = "true"
  }

  set {
    name  = "nodePort.enabled"
    value = "true"
  }

  set {
      name  = "k8sServicePort"
      value = "7445"
  }
}

resource "talos_machine_secrets" "secrets" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "client_configuration" {
  depends_on = [talos_machine_secrets.secrets, module.kubernetes-masters, module.kubernetes-workers]
  client_configuration = talos_machine_secrets.secrets.client_configuration
  cluster_name         = local.cluster_name
  nodes                = concat(local.master_node_ips, local.worker_node_ips)
  endpoints            = local.master_node_ips
}

data "talos_machine_configuration" "control_plane" {
  count      = length(module.kubernetes-masters)

  talos_version    = var.talos_version
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  docs             = false
  examples         = false
  cluster_name     = local.cluster_name
  machine_secrets  = talos_machine_secrets.secrets.machine_secrets
  config_patches = [
    templatefile("${path.module}/templates/master.yaml.tpl", {
      HOSTNAME        = local.master_node_names[count.index],
      NODE_IP         = local.master_node_ips[count.index],
      VIP             = local.cluster_ip,
      TALOS_IMAGE     = local.installer,
      CILIUM_MANIFEST = yamlencode(data.helm_template.cilium_template.manifest),
    }),
  ]
}

data "talos_machine_configuration" "worker" {
  count = length(module.kubernetes-workers)

  talos_version    = var.talos_version
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  docs             = false
  examples         = false
  cluster_name     = local.cluster_name
  machine_secrets  = talos_machine_secrets.secrets.machine_secrets
  config_patches = [
    templatefile("${path.module}/templates/worker.yaml.tpl", {
      HOSTNAME    = local.worker_node_names[count.index],
      NODE_IP     = local.worker_node_ips[count.index],
      TALOS_IMAGE = local.installer,
    }),
  ]
}

resource "talos_machine_configuration_apply" "control_plane" {
  count      = length(module.kubernetes-masters)
  depends_on = [talos_machine_secrets.secrets, data.talos_machine_configuration.control_plane]

  client_configuration        = talos_machine_secrets.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[count.index].machine_configuration
  node                        = module.kubernetes-masters[count.index].node_ip
}

resource "talos_machine_configuration_apply" "worker" {
  count      = length(module.kubernetes-workers)
  depends_on = [talos_machine_secrets.secrets, data.talos_machine_configuration.worker]

  client_configuration        = talos_machine_secrets.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[count.index].machine_configuration
  node                        = module.kubernetes-workers[count.index].node_ip
}

resource "talos_machine_bootstrap" "bootstrap" {
  count      = length(module.kubernetes-masters) > 0 ? 1 : 0
  depends_on = [talos_machine_configuration_apply.control_plane, talos_machine_configuration_apply.worker]

  client_configuration = talos_machine_secrets.secrets.client_configuration
  node = module.kubernetes-masters[0].node_ip
}

# Save the configurations to disk
resource "local_file" "config" {
  count    = length(module.kubernetes-masters) > 0 ? 1 : 0
  content  = data.talos_client_configuration.client_configuration.talos_config
  filename = "${var.talos_directory}/talosconfig"
}

resource "null_resource" "health_check" {
  depends_on = [talos_machine_bootstrap.bootstrap, local_file.config]
  count      = length(module.kubernetes-masters) > 0 ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/health_check.sh -p ${module.kubernetes-masters[0].node_ip} -t ${var.talos_directory} -c ${local.cluster_name} -u ${var.github_username} -r ${var.github_repository} -k ${var.github_token} -w ${join(",", module.kubernetes-workers.*.node_name)} -m ${join(",", module.kubernetes-masters.*.node_ip)} -i ${join(",", module.kubernetes-workers.*.node_ip)}"
  }
}

