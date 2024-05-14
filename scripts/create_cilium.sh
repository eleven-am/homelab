#!/bin/bash

# This function return the cilium return as a string
create_cilium() {
   echo "[INFO] Creating cilium.yaml file..."

   # Create the cilium.yaml file
   cilium_yaml=$(helm template \
      cilium \
      cilium/cilium \
      --version 1.14.0 \
      --namespace kube-system \
      --set ipam.mode=kubernetes \
      --set=kubeProxyReplacement=true \
      --set=securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
      --set=securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
      --set=cgroup.autoMount.enabled=false \
      --set=cgroup.hostRoot=/sys/fs/cgroup \
      --set prometheus.enabled=true \
      --set=k8sServiceHost=localhost \
      --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}" \
      --set hubble.relay.enabled=true \
      --set hubble.ui.enabled=true \
      --set ingressController.enabled=true \
      --set l2announcements.enabled=true \
      --set k8sClientRateLimit.qps="{QPS}" \
      --set k8sClientRateLimit.burst="{BURST}" \
      --set=k8sServicePort=7445)

   echo "[INFO] cilium.yaml file created successfully"

  # Add 4 tabs to every line in the cilium_yaml
  cilium_yaml=$(echo "$cilium_yaml" | sed 's/^/       /g')
}

# This function generates a machine config patch file
# It assumes the first argument is the machine_os_image
generate_machine_config_patch() {
    local machine_os_image=$1

    echo "[INFO] Generating machine-config-patch.yaml file..."

    # Run the create_cilium function
    create_cilium

   # Create the machine-config-patch.yaml file
cat <<EOF > machine-config-patch.yaml
machine:
  network:
    nameservers:
      - 1.1.1.1
      - 8.8.8.8
  features:
    kubePrism:
      enabled: true
      port: 7445
  install:
    image: $machine_os_image
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
  inlineManifests:
    - name: cilium
      contents: |
$cilium_yaml
EOF

    echo "[INFO] machine-config-patch.yaml file created successfully"
}

# This function generates the talos configuration
# It assumes the first argument is the talos directory,
# the second argument is the cluster name,
# the third argument is primary endpoint and
# the fourth argument is the machine_os_image
generate_talos_config() {
    local talos_dir=$1
    local cluster_name=$2
    local primary_endpoint=$3
    local machine_os_image=$4

    # Run the generate_machine_config_patch function
    generate_machine_config_patch "$machine_os_image"

    echo "[INFO] Preparing to generate talos configuration file..."

    # Delete anc recreate the talos directory
    rm -rf "$talos_dir" && mkdir -p "$talos_dir"

    echo "[INFO] Generating talos configuration file..."

    # Create the talos configuration file
    talosctl gen config "$cluster_name" "$primary_endpoint" --output-dir "$talos_dir" --config-patch @machine-config-patch.yaml

    # Sleep for 20 seconds to allow the talos configuration to be generated
    sleep 20

    echo "[INFO] Talos configuration file created successfully"

    echo "[INFO] Cleaning up..."

    # Delete the machine-config-patch.yaml file
    rm machine-config-patch.yaml

    echo "[INFO] Clean up completed successfully"
}

build_args() {
  local talos_dir=""
  local cluster_name=""
  local primary_endpoint=""
  local machine_os_image=""

  while test $# -gt 0; do
      case "$1" in
          -t|--talos-dir)
              shift
              talos_dir=$1
              shift
              ;;
          -c|--cluster-name)
              shift
              cluster_name=$1
              shift
              ;;
          -p|--primary-endpoint)
              shift
              primary_endpoint=$1
              shift
              ;;
          -m|--machine-os-image)
              shift
              machine_os_image=$1
              shift
              ;;
          *)
              break
              ;;
      esac
  done

  if [[ -z "$talos_dir" || -z "$cluster_name" || -z "$primary_endpoint" || -z "$machine_os_image" ]]; then
    echo "[ERROR] Missing required arguments"
    exit 0
  fi

  generate_talos_config "$talos_dir" "$cluster_name" "$primary_endpoint" "$machine_os_image"
}

build_args "$@"
