# Combine outputs from all modules to provide a comprehensive service URL list
output "homelab_services" {
  description = "URLs for all configured homelab services"
  value = merge(
    module.media.media_service_urls,
    module.home_automation.automation_service_urls,
    module.dashboard.dashboard_service_urls
  )
}

# Network information
output "networks" {
  description = "Docker networks created for the homelab"
  value = {
    traefik = module.core.traefik_network_id
    media   = module.core.media_network_id
  }
}

# Storage information
output "storage_info" {
  description = "Information about configured storage"
  value = {
    mergerfs_path = var.mergerfs_mount_path
    disk_count    = length(var.storage_disks)
  }
}

# Tailscale IP (if available)
output "tailscale_ip" {
  description = "Tailscale IP address for remote access"
  value       = module.networking.tailscale_ip
}