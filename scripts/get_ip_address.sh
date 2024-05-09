#!/bin/bash

# This function assumes that the first argument is a MAC address
rewrite_mac_address() {
  # Split MAC address by colon
  IFS=':' read -r -a mac_address <<< "$1"

  # Join MAC address by colon
  new_mac_address=$(IFS=':'; echo "${mac_address[*]}")
}

# This function assumes that the first argument is a the three first octets of the IP address
ping_all() {
  # Ping all addresses in the subnet
  for i in $(seq 1 254); do
    ping -c 1 -q "$1"."$i" > /dev/null 2>&1 &
  done
}

# This function assumes that the first argument is a MAC address
get_ip_from_mac() {
  # Find all IP addresses in the ARP table that match the MAC address and get the first one
  address=$(arp -a | grep "$1" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -n 1)
}

# This function assumes that the first argument is an CIDR IP address
get_three_first_octets() {
  # Split IP address by dots and get the first three octets
  echo "$1" | cut -d '.' -f 1-3
}

# This function assumes that the first argument is a MAC address and the second argument is the CIDR IP address
main() {
  rewrite_mac_address "$1"

  # Set mac address to lowercase
  new_mac_address=$(echo "$new_mac_address" | tr '[:upper:]' '[:lower:]')

  # Get IP address from MAC address the first time if it fails
  get_ip_from_mac "$new_mac_address"

  # If the IP address is not found, ping all addresses in the subnet
  if [ -z "$address" ]; then
    first_three_octets=$(get_three_first_octets "$2")
    ping_all "$first_three_octets"
  else
    jq -n --arg address "$address" '{"address":$address}'
    exit 0
  fi

  # Try to get the IP address from the MAC address again
  get_ip_from_mac "$new_mac_address"

  # If the IP address is found, return it
  if [ -n "$address" ]; then
    jq -n --arg address "$address" '{"address":$address}'
    exit 0
  else
    echo "Maximum retries reached. Address not found."
    exit 1
  fi
}

main "$@"
