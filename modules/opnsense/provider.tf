terraform {
  required_providers {
	proxmox = {
	  source = "telmate/proxmox"
	  version = "3.0.1-rc1"
	}
  }
}

provider "proxmox" {
  pm_api_url 		  = var.proxmox_host
  pm_api_token_id 	  = var.proxmox_username
  pm_api_token_secret = var.proxmox_token
  pm_tls_insecure 	  = true
}
