#!/bin/bash

# This function assumes that the first argument is the bastian host, the second argument is the mac address, the third argument is the subnet and the fourth argument is the location of the ssh key
main() {
  local bastian_host=$1
  local mac_address=$2
  local subnet=$3
  local ssh_key=$4

  # Get the IP address from the MAC address
  ssh -i "${ssh_key}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${bastian_host}" "bash -s" < scripts/get_ip_address.sh "${mac_address}" "${subnet}"
}

# This function builds the arguments for the main function
build_args() {
  local bastian_host=""
  local mac_address=""
  local subnet=""
  local ssh_key=""

  while getopts "b:m:s:k:" opt; do
    case ${opt} in
      b )
        bastian_host=$OPTARG
        ;;
      m )
        mac_address=$OPTARG
        ;;
      s )
        subnet=$OPTARG
        ;;
      k )
        ssh_key=$OPTARG
        ;;
      \? )
        echo "Usage: cmd -b bastian_host -m mac_address -s subnet -k ssh_key"
        exit 1
        ;;
    esac
  done

  if [[ -z "$bastian_host" || -z "$mac_address" || -z "$subnet" || -z "$ssh_key" ]]; then
    echo "[ERROR] Usage: cmd -b bastian_host -m mac_address -s subnet -k ssh_key"
    exit 1
  fi

  main "$bastian_host" "$mac_address" "$subnet" "$ssh_key"
}

build_args "$@"
