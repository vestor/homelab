# Connection Variables
variable "ssh_host" {
  description = "CoreOS machine hostname or IP"
  type        = string
}

variable "ssh_user" {
  description = "SSH username for CoreOS machine"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
}

# Service Variables
variable "domain_name" {
  description = "Base domain name for Traefik routing"
  type        = string
}

variable "timezone" {
  description = "Local timezone for containers"
  type        = string
  default     = "UTC"
}

variable "mergerfs_mount_path" {
  description = "Path where mergerfs will mount the combined storage"
  type        = string
}

# Network Variables
variable "traefik_network_id" {
  description = "ID of the Traefik network"
  type        = string
}

variable "media_network_id" {
  description = "ID of the media services network"
  type        = string
}

# Volume Variables
variable "radarr_config_vol" {
  description = "Docker volume for Radarr configuration"
  type        = string
}

variable "sonarr_config_vol" {
  description = "Docker volume for Sonarr configuration"
  type        = string
}

variable "prowlarr_config_vol" {
  description = "Docker volume for Prowlarr configuration"
  type        = string
}

variable "qbittorrent_config_vol" {
  description = "Docker volume for qBittorrent configuration"
  type        = string
}

variable "jellyfin_config_vol" {
  description = "Docker volume for Jellyfin configuration"
  type        = string
}

variable "jellyfin_cache_vol" {
  description = "Docker volume for Jellyfin cache"
  type        = string
}

variable "bazarr_config_vol" {
  description = "Docker volume for Bazarr configuration"
  type        = string
}

variable "jellyseerr_config_vol" {
  description = "Docker volume for Jellyseerr configuration"
  type        = string
}

variable "byparr_config_vol" {
  description = "Docker volume for Byparr configuration"
  type        = string
}