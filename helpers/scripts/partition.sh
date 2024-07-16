#!/bin/bash

# Create 3 partitions of 500GiB each
sgdisk -n 1:+0:+500GiB /dev/nvme0n1
sgdisk -n 2:+0:+500GiB /dev/nvme0n1
sgdisk -n 3:+0:+500GiB /dev/nvme0n1

# Create 3 partitions of 50GiB each
sgdisk -n 4:+0:+50GiB /dev/nvme0n1
sgdisk -n 5:+0:+50GiB /dev/nvme0n1
sgdisk -n 6:+0:+50GiB /dev/nvme0n1

# Create the final partition with the remaining space
sgdisk -n 7:+0:+0 /dev/nvme0n1

# Confirm partition
sgdisk -p /dev/nvme0n1

# Create a role with the necessary privileges
pveum role add Terraform -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use"

# Create a user with the role
pveum user add terraform@pve -password terraform -comment "Terraform User" -role Terraform
