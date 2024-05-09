variable subnet {
  description = "The subnet for the cluster"
  type        = string
}

variable ip_offset {
  description = "The offset for the IP addresses"
  type        = number
}

variable number_of_ips {
  description = "The number of IP addresses to allocate"
  type        = number
}
