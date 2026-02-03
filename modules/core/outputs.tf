# Network outputs
output "traefik_network_id" {
  description = "ID of the Traefik network"
  value       = docker_network.traefik_net.id
}

output "media_network_id" {
  description = "ID of the media services network"
  value       = docker_network.media_net.id
}

# Container outputs
output "socket_proxy_name" {
  description = "Name of the Docker socket proxy container"
  value       = docker_container.socket_proxy.name
}

# Volume outputs - for media services
output "radarr_config_vol" {
  description = "Docker volume for Radarr configuration"
  value       = docker_volume.volumes["radarr_config"].name
}

output "sonarr_config_vol" {
  description = "Docker volume for Sonarr configuration"
  value       = docker_volume.volumes["sonarr_config"].name
}

output "prowlarr_config_vol" {
  description = "Docker volume for Prowlarr configuration"
  value       = docker_volume.volumes["prowlarr_config"].name
}

output "qbittorrent_config_vol" {
  description = "Docker volume for qBittorrent configuration"
  value       = docker_volume.volumes["qbittorrent_config"].name
}

output "jellyfin_config_vol" {
  description = "Docker volume for Jellyfin configuration"
  value       = docker_volume.volumes["jellyfin_config"].name
}

output "jellyfin_cache_vol" {
  description = "Docker volume for Jellyfin cache"
  value       = docker_volume.volumes["jellyfin_cache"].name
}

output "bazarr_config_vol" {
  description = "Docker volume for Bazarr configuration"
  value       = docker_volume.volumes["bazarr_config"].name
}

output "jellyseerr_config_vol" {
  description = "Docker volume for Jellyseerr configuration"
  value       = docker_volume.volumes["jellyseerr_config"].name
}

output "byparr_config_vol" {
  description = "Docker volume for ByParr configuration"
  value       = docker_volume.volumes["byparr_config"].name
}

# Volume outputs - for networking
output "traefik_config_vol" {
  description = "Docker volume for Traefik configuration"
  value       = docker_volume.volumes["traefik_config"].name
}

output "traefik_acme_vol" {
  description = "Docker volume for Traefik ACME/Let's Encrypt data"
  value       = docker_volume.volumes["traefik_acme"].name
}

output "tailscale_data_vol" {
  description = "Docker volume for Tailscale data"
  value       = docker_volume.volumes["tailscale_data"].name
}

# Volume outputs - for home automation
output "homeassistant_config_vol" {
  description = "Docker volume for Home Assistant configuration"
  value       = docker_volume.volumes["homeassistant_config"].name
}

output "hyperhdr_config_vol" {
  description = "Docker volume for HyperHDR configuration"
  value       = docker_volume.volumes["hyperhdr_config"].name
}

# Volume outputs - for dashboards and management
output "homepage_config_vol" {
  description = "Docker volume for Homepage configuration"
  value       = docker_volume.volumes["homepage_config"].name
}

output "watchtower_config_vol" {
  description = "Docker volume for Watchtower configuration"
  value       = docker_volume.volumes["watchtower_config"].name
}

output "whatsup_docker_data_vol" {
  description = "Docker volume for What's Up Docker data"
  value       = docker_volume.volumes["whatsup_docker_data"].name
}

# Volume outputs - for gaming
output "palworld_config_vol" {
  description = "Docker volume for Palworld configuration"
  value       = docker_volume.volumes["palworld_config"].name
}