terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.5"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.35.0"
    }
  }
}

provider "docker" {
  host = "ssh://${var.ssh_user}@${var.ssh_host}"
  ssh_opts = [
    "-i", "${var.ssh_key_path}",
    "-o", "StrictHostKeyChecking=no",
    "-o", "ConnectTimeout=120",
    "-o", "ServerAliveInterval=15",
    "-o", "ServerAliveCountMax=30",
    "-o", "TCPKeepAlive=yes"
  ]
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Core infrastructure module - networks, socket proxy, etc.
module "core" {
  source = "./modules/core"

  ssh_host      = var.ssh_host
  ssh_user      = var.ssh_user
  ssh_key_path  = var.ssh_key_path
  timezone      = var.timezone
}

# Storage management module
module "storage" {
  source = "./modules/storage"

  ssh_host            = var.ssh_host
  ssh_user            = var.ssh_user
  ssh_key_path        = var.ssh_key_path
  mergerfs_mount_path = var.mergerfs_mount_path
  storage_disks       = var.storage_disks
  storage_mount_base  = var.storage_mount_base

  depends_on = [module.core]
}

# Networking module - Traefik, Tailscale, DNS
module "networking" {
  source = "./modules/networking"

  ssh_host            = var.ssh_host
  ssh_user            = var.ssh_user
  ssh_key_path        = var.ssh_key_path
  domain_name         = var.domain_name
  local_ip            = var.local_ip
  timezone            = var.timezone
  tailscale_auth_key  = var.tailscale_auth_key
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_email    = var.cloudflare_email
  cloudflare_zone_id  = var.cloudflare_zone_id

  traefik_network_id  = module.core.traefik_network_id
  traefik_config_vol  = module.core.traefik_config_vol
  traefik_acme_vol    = module.core.traefik_acme_vol
  tailscale_data_vol  = module.core.tailscale_data_vol
  socket_proxy_name   = module.core.socket_proxy_name

  depends_on = [module.core]
}

# Media services module - Jellyfin, Radarr, Sonarr, etc.
module "media" {
  source = "./modules/media"

  ssh_host            = var.ssh_host
  ssh_user            = var.ssh_user
  ssh_key_path        = var.ssh_key_path
  domain_name         = var.domain_name
  timezone            = var.timezone
  mergerfs_mount_path = var.mergerfs_mount_path

  traefik_network_id  = module.core.traefik_network_id
  media_network_id    = module.core.media_network_id

  # Pass volumes from core module
  radarr_config_vol     = module.core.radarr_config_vol
  sonarr_config_vol     = module.core.sonarr_config_vol
  prowlarr_config_vol   = module.core.prowlarr_config_vol
  qbittorrent_config_vol = module.core.qbittorrent_config_vol
  jellyfin_config_vol   = module.core.jellyfin_config_vol
  jellyfin_cache_vol    = module.core.jellyfin_cache_vol
  bazarr_config_vol     = module.core.bazarr_config_vol
  seerr_config_vol = module.core.seerr_config_vol
  byparr_config_vol = module.core.byparr_config_vol


  depends_on = [
    module.core,
    module.storage,
    module.networking
  ]
}

# Home automation module
module "home_automation" {
  source = "./modules/home_automation"

  ssh_host            = var.ssh_host
  ssh_user            = var.ssh_user
  ssh_key_path        = var.ssh_key_path
  domain_name         = var.domain_name
  timezone            = var.timezone

  traefik_network_id  = module.core.traefik_network_id

  homeassistant_config_vol = module.core.homeassistant_config_vol
  hyperhdr_config_vol      = module.core.hyperhdr_config_vol

  depends_on = [
    module.core,
    module.networking
  ]
}

# Dashboards and management services
module "dashboard" {
  source = "./modules/dashboard"

  ssh_host            = var.ssh_host
  ssh_user            = var.ssh_user
  ssh_key_path        = var.ssh_key_path
  domain_name         = var.domain_name
  timezone            = var.timezone
  mergerfs_mount_path = var.mergerfs_mount_path

  traefik_network_id  = module.core.traefik_network_id
  socket_proxy_name   = module.core.socket_proxy_name

  homepage_config_vol     = module.core.homepage_config_vol
  whatsup_docker_data_vol = module.core.whatsup_docker_data_vol
  glance_config_vol       = module.core.glance_config_vol

  depends_on = [
    module.core,
    module.networking
  ]
}

# Gaming servers
module "gaming" {
  source = "./modules/gaming"

  ssh_host            = var.ssh_host
  ssh_user            = var.ssh_user
  ssh_key_path        = var.ssh_key_path
  domain_name         = var.domain_name
  timezone            = var.timezone

  traefik_network_id         = module.core.traefik_network_id
  palworld_config_vol        = module.core.palworld_config_vol
  palworld_toggle_data_vol   = module.core.palworld_toggle_data_vol
  palworld_server_password   = var.palworld_server_password
  palworld_admin_password    = var.palworld_admin_password
  palworld_player_count      = var.palworld_player_count
  palworld_server_name       = var.palworld_server_name
  palworld_server_description = var.palworld_server_description
  public_ip                  = var.public_ip
  paledit_password           = var.paledit_password

  depends_on = [module.core]
}