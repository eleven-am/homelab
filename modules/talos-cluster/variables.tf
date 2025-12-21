variable "proxmox_endpoint" {
  description = "The Proxmox API endpoint URL (e.g., https://192.168.1.6:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "The Proxmox API token in format 'user@realm!tokenid=secret'"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "The Proxmox node name to deploy VMs on"
  type        = string
}

variable "proxmox_storage" {
  description = "The Proxmox storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "iso_storage" {
  description = "The Proxmox storage pool for ISO/images"
  type        = string
  default     = "local"
}

variable "talos_version" {
  description = "The Talos Linux version to deploy"
  type        = string
  default     = "v1.11.6"
}

variable "kubernetes_version" {
  description = "The Kubernetes version to deploy"
  type        = string
  default     = "1.34.1"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "talos-cluster"
}

variable "cluster_vip" {
  description = "Virtual IP for the cluster control plane (optional)"
  type        = string
  default     = ""
}

variable "enable_nvidia_gpu" {
  description = "Enable NVIDIA GPU support with proprietary drivers"
  type        = bool
  default     = false
}

variable "nvidia_driver_version" {
  description = "NVIDIA driver version (must match Talos version)"
  type        = string
  default     = "550.144.03"
}

variable "extra_extensions" {
  description = "Additional Talos extensions to include"
  type        = list(string)
  default     = []
}

variable "subnet" {
  description = "Subnet for the cluster nodes (e.g., 192.168.101.0/24)"
  type        = string
}

variable "gateway" {
  description = "Gateway IP (defaults to first IP in subnet)"
  type        = string
  default     = ""
}

variable "nameservers" {
  description = "DNS nameservers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = "VLAN tag (-1 for no VLAN)"
  type        = number
  default     = -1
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "control_plane_ip_offset" {
  description = "IP offset for control plane nodes within subnet"
  type        = number
  default     = 10
}

variable "control_plane_cores" {
  description = "Number of CPU cores for control plane nodes"
  type        = number
  default     = 4
}

variable "control_plane_memory" {
  description = "Memory in MB for control plane nodes"
  type        = number
  default     = 8192
}

variable "control_plane_disk_size" {
  description = "Disk size in GB for control plane nodes"
  type        = number
  default     = 50
}

variable "control_plane_vm_id_start" {
  description = "Starting VM ID for control plane nodes"
  type        = number
  default     = 600
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 0
}

variable "worker_ip_offset" {
  description = "IP offset for worker nodes within subnet"
  type        = number
  default     = 20
}

variable "worker_cores" {
  description = "Number of CPU cores for worker nodes"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 8192
}

variable "worker_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 50
}

variable "worker_vm_id_start" {
  description = "Starting VM ID for worker nodes"
  type        = number
  default     = 700
}

variable "gpu_passthrough_enabled" {
  description = "Enable GPU passthrough for worker nodes"
  type        = bool
  default     = false
}

variable "gpu_mapping" {
  description = "Name of the Proxmox PCI resource mapping for the GPU"
  type        = string
  default     = ""
}

variable "enable_flux" {
  description = "Enable FluxCD bootstrap"
  type        = bool
  default     = true
}

variable "github_username" {
  description = "GitHub username for FluxCD"
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository for FluxCD"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub token for FluxCD"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sops_age_key" {
  description = "SOPS age key for secret decryption"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.16.5"
}

variable "enable_hubble" {
  description = "Enable Hubble observability"
  type        = bool
  default     = true
}

variable "enable_gateway_api" {
  description = "Enable Gateway API support (disabled - using Envoy Gateway instead)"
  type        = bool
  default     = false
}

variable "output_directory" {
  description = "Directory to store talosconfig and kubeconfig"
  type        = string
  default     = "talos"
}

variable "export_configs" {
  description = "Export kubeconfig and talosconfig to ~/.kube/config and ~/.talos/config"
  type        = bool
  default     = true
}
