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

# This function assumes that the first argument is a github username, the second argument is a github repository name,
# the third argument is the github token and the fourth argument is the cluster name
# It initializes the fluxcd
initialize_fluxcd() {
  local github_username=$1
  local github_repo=$2
  local github_token=$3
  local cluster_name=$4

  echo "[INFO] Initializing the fluxcd"
  flux bootstrap github \
    --owner="${github_username}" \
    --repository="${github_repo}" \
    --branch=main \
    --path=clusters/"${cluster_name}" \
    --personal \
    --token-auth \
    --token="${github_token}"

  echo "[INFO] Successfully initialized the fluxcd"
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

# This function assumes that the first argument is an IP address, the second argument is the talos directory
# the third argument is a github username, the fourth argument is a github repository name,
# the fifth argument is the github token and the sixth argument is the cluster name
# It starts the health check and kubeconfig update process
main() {
  local primary_controller=$1
  local talos_dir=$2
  local github_username=$3
  local github_repo=$4
  local github_token=$5
  local cluster_name=$6

  update_kubeconfig "${primary_controller}" "${talos_dir}"
  check_health "${primary_controller}" "${talos_dir}"
  initialize_fluxcd "${github_username}" "${github_repo}" "${github_token}" "${cluster_name}"
}

# This function builds the arguments for the main function
build_args() {
  local primary_controller=""
  local talos_dir=""
  local cluster_name=""
  local github_username=""
  local github_repo=""
  local github_token=""

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
          -c|--cluster-name)
              shift
              cluster_name=$1
              shift
              ;;
          -u|--github-username)
              shift
              github_username=$1
              shift
              ;;
          -r|--github-repo)
              shift
              github_repo=$1
              shift
              ;;
          -k|--github-token)
              shift
              github_token=$1
              shift
              ;;
          *)
              break
              ;;
      esac
  done

  main "${primary_controller}" "${talos_dir}" "${github_username}" "${github_repo}" "${github_token}" "${cluster_name}"
}

build_args "$@"
