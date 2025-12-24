data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }

  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }

  # Enable VXLAN tunnel mode (required for multicast)
  set {
    name  = "routingMode"
    value = "tunnel"
  }

  set {
    name  = "tunnelProtocol"
    value = "vxlan"
  }

  # Enable multicast for mDNS auto-discovery
  set {
    name  = "multicast.enabled"
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
    name  = "k8sServiceHost"
    value = "localhost"
  }

  set {
    name  = "k8sServicePort"
    value = "7445"
  }

  set {
    name  = "hubble.relay.enabled"
    value = tostring(var.enable_hubble)
  }

  set {
    name  = "hubble.ui.enabled"
    value = tostring(var.enable_hubble)
  }

  dynamic "set" {
    for_each = var.enable_hubble ? [1] : []
    content {
      name  = "hubble.metrics.enabled"
      value = "{dns,drop,tcp,flow,icmp,http}"
    }
  }

  set {
    name  = "gatewayAPI.enabled"
    value = tostring(var.enable_gateway_api)
  }

  set {
    name  = "nodePort.enabled"
    value = "true"
  }

  set {
    name  = "bgpControlPlane.enabled"
    value = "true"
  }

  set {
    name  = "l2announcements.enabled"
    value = "true"
  }

  set {
    name  = "externalIPs.enabled"
    value = "true"
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = concat(local.control_plane_ips, local.worker_ips)
  endpoints            = local.control_plane_ips
}

data "talos_machine_configuration" "control_plane" {
  count = var.control_plane_count

  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  docs               = false
  examples           = false

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname    = "${var.cluster_name}-cp-${count.index}"
          nameservers = var.nameservers
          interfaces = [{
            addresses = ["${local.control_plane_ips[count.index]}/${local.subnet_cidr}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = local.gateway
            }]
            deviceSelector = {
              physical = true
            }
            vip = var.control_plane_count > 0 ? {
              ip = local.cluster_vip
            } : null
          }]
        }
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
          kubernetesTalosAPIAccess = {
            enabled                     = true
            allowedRoles                = ["os:reader"]
            allowedKubernetesNamespaces = ["kube-system"]
          }
        }
        install = {
          image = local.installer_image
        }
        kernel = var.enable_nvidia_gpu ? {
          modules = [
            { name = "nvidia" },
            { name = "nvidia_uvm" },
            { name = "nvidia_drm" },
            { name = "nvidia_modeset" },
          ]
        } : null
        sysctls = var.enable_nvidia_gpu ? {
          "net.core.bpf_jit_harden" = "1"
        } : null
      }
      cluster = {
        allowSchedulingOnControlPlanes = true
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
        inlineManifests = [{
          name     = "cilium"
          contents = data.helm_template.cilium.manifest
        }]
      }
    })
  ]
}

data "talos_machine_configuration" "worker" {
  count = var.worker_count

  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  docs               = false
  examples           = false

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname    = "${var.cluster_name}-worker-${count.index}"
          nameservers = var.nameservers
          interfaces = [{
            addresses = ["${local.worker_ips[count.index]}/${local.subnet_cidr}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = local.gateway
            }]
            deviceSelector = {
              physical = true
            }
          }]
        }
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
        install = {
          image = local.installer_image
        }
        kernel = var.enable_nvidia_gpu ? {
          modules = [
            { name = "nvidia" },
            { name = "nvidia_uvm" },
            { name = "nvidia_drm" },
            { name = "nvidia_modeset" },
          ]
        } : null
        sysctls = var.enable_nvidia_gpu ? {
          "net.core.bpf_jit_harden" = "1"
        } : null
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "control_plane" {
  count = var.control_plane_count

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[count.index].machine_configuration
  node                        = local.control_plane_actual_ips[count.index]

  depends_on = [proxmox_virtual_environment_vm.control_plane]
}

resource "talos_machine_configuration_apply" "worker" {
  count = var.worker_count

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[count.index].machine_configuration
  node                        = local.worker_actual_ips[count.index]

  depends_on = [proxmox_virtual_environment_vm.worker]
}

resource "null_resource" "wait_for_install" {
  count = var.control_plane_count > 0 ? 1 : 0

  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [talos_machine_configuration_apply.control_plane]
}

resource "talos_machine_bootstrap" "this" {
  count = var.control_plane_count > 0 ? 1 : 0

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_ips[0]

  depends_on = [null_resource.wait_for_install]
}

data "talos_cluster_kubeconfig" "this" {
  count = var.control_plane_count > 0 ? 1 : 0

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_ips[0]

  depends_on = [talos_machine_bootstrap.this]
}

resource "local_file" "talosconfig" {
  count = var.control_plane_count > 0 ? 1 : 0

  content         = data.talos_client_configuration.this.talos_config
  filename        = "${var.output_directory}/talosconfig"
  file_permission = "0600"
}

resource "local_file" "kubeconfig" {
  count = var.control_plane_count > 0 ? 1 : 0

  content         = data.talos_cluster_kubeconfig.this[0].kubeconfig_raw
  filename        = "${var.output_directory}/kubeconfig"
  file_permission = "0600"
}

resource "null_resource" "export_kubeconfig" {
  count = var.control_plane_count > 0 && var.export_configs ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ~/.kube
      cp ${var.output_directory}/kubeconfig ~/.kube/config
      chmod 600 ~/.kube/config
      echo "Kubeconfig exported to ~/.kube/config"
    EOT
  }

  depends_on = [local_file.kubeconfig, null_resource.wait_for_cluster]
}

resource "null_resource" "export_talosconfig" {
  count = var.control_plane_count > 0 && var.export_configs ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ~/.talos
      cp ${var.output_directory}/talosconfig ~/.talos/config
      chmod 600 ~/.talos/config
      echo "Talosconfig exported to ~/.talos/config"
    EOT
  }

  depends_on = [local_file.talosconfig, null_resource.wait_for_cluster]
}
