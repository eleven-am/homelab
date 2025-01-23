#!/bin/bash

if [ $# -ne 1 ]; then
   echo "Usage: $0 <vmid>"
   exit 1
fi

VMID=$1

# Add mount point
pct set "$VMID" -mp0 /snow/media,mp=/media

# Add ID mappings to config file
cat >> /etc/pve/lxc/"$VMID".conf << EOF
lxc.idmap: u 0 1005 1
lxc.idmap: g 0 1005 1
lxc.idmap: u 1 100000 65535
lxc.idmap: g 1 100000 65535
EOF

# Restart container
pct restart "$VMID"

echo "Mount point and ID mappings configured for container $VMID"

