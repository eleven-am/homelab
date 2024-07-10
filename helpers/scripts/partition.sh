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
