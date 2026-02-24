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

output "seerr_config_vol" {
  description = "Docker volume for Seerr configuration"
  value       = docker_volume.volumes["seerr_config"].name
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
output "whatsup_docker_data_vol" {
  description = "Docker volume for What's Up Docker data"
  value       = docker_volume.volumes["whatsup_docker_data"].name
}

output "glance_config_vol" {
  description = "Docker volume for Glance configuration"
  value       = docker_volume.volumes["glance_config"].name
}

# Volume outputs - for storage monitoring
output "scrutiny_config_vol" {
  description = "Docker volume for Scrutiny configuration"
  value       = docker_volume.volumes["scrutiny_config"].name
}

output "scrutiny_influxdb_vol" {
  description = "Docker volume for Scrutiny InfluxDB data"
  value       = docker_volume.volumes["scrutiny_influxdb"].name
}

# Volume outputs - for gaming
output "palworld_config_vol" {
  description = "Docker volume for Palworld configuration"
  value       = docker_volume.volumes["palworld_config"].name
}

output "palworld_toggle_data_vol" {
  description = "Docker volume for Palworld toggle service data"
  value       = docker_volume.volumes["palworld_toggle_data"].name
}

# Volume outputs - for network monitoring
output "speedtest_config_vol" {
  description = "Docker volume for Speedtest Tracker configuration"
  value       = docker_volume.volumes["speedtest_config"].name
}

output "uptime_kuma_data_vol" {
  description = "Docker volume for Uptime Kuma data"
  value       = docker_volume.volumes["uptime_kuma_data"].name
}

# Volume outputs - for monitoring stack
output "prometheus_config_vol" {
  description = "Docker volume for Prometheus configuration"
  value       = docker_volume.volumes["prometheus_config"].name
}

output "prometheus_data_vol" {
  description = "Docker volume for Prometheus time-series data"
  value       = docker_volume.volumes["prometheus_data"].name
}

output "grafana_data_vol" {
  description = "Docker volume for Grafana data"
  value       = docker_volume.volumes["grafana_data"].name
}