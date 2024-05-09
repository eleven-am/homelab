#!/bin/bash

# This function assumes that the first argument is an IP address and the second argument is the talos directory
# It checks the health of the cluster
check_health() {
  local primary_controller=$1
  local n=0
  local retries=5
  local talos_dir=$2

  echo "[INFO] Performing health check on the cluster"

  until [ "$n" -ge "$retries" ]; do
    if talosctl --talosconfig="${talos_dir}"/talosconfig --nodes "${primary_controller}" -e "${primary_controller}" health; then
      break
    else
      n=$((n+1))
      sleep 5
    fi
  done

  echo "[INFO] Successfully performed health check on the cluster"
}

# This function assumes that the first argument is an IP address and the second argument is the talos directory
# It updates the kubeconfig
update_kubeconfig() {
  local primary_controller=$1
  local talos_dir=$2

  echo "[INFO] Setting the TALOSCONFIG environment variable"
  export TALOSCONFIG="${talos_dir}"/talosconfig

  echo "[INFO] Retrieving the kubeconfig for the cluster"
  talosctl kubeconfig --nodes "${primary_controller}" -e "${primary_controller}" --talosconfig="${talos_dir}"/talosconfig --force

  echo "[INFO] Setting the endpoint and node values for the talosctl command"
  talosctl config endpoint "${primary_controller}"
  talosctl config node "${primary_controller}"

  echo "[INFO] Successfully retrieved the kubeconfig from the cluster"
}

# This function assumes that the first argument is an IP address and the second argument is the talos directory
# It starts the health check and kubeconfig update process
main() {
  local primary_controller=$1
  local talos_dir=$2

  update_kubeconfig "${primary_controller}" "${talos_dir}"
  check_health "${primary_controller}" "${talos_dir}"
}

# This function builds the arguments for the main function
build_args() {
  local primary_controller=""
  local talos_dir=""

   while test $# -gt 0; do
      case "$1" in
          -p|--primary-controller)
              shift
              primary_controller=$1
              shift
              ;;
          -t|--talos-dir)
              shift
              talos_dir=$1
              shift
              ;;
          *)
              break
              ;;
      esac
  done

  main "${primary_controller}" "${talos_dir}"
}

build_args "$@"
