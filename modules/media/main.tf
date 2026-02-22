locals {
  # Define common storage paths
  media_path = "${var.mergerfs_mount_path}/media"
  downloads_path = "${var.mergerfs_mount_path}/downloads"

  # Common network configuration
  networks = [var.traefik_network_id, var.media_network_id]
}

# Jellyfin media server
module "jellyfin" {
  source = "../service_template"

  service_name  = "jellyfin"
  image         = "jellyfin/jellyfin:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  privileged    = false
  network_ids   = local.networks

  web_port     = 8096
  port_mappings = [
    {
      internal = 8096
      external = 8096
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.jellyfin_config_vol
      container_path = "/config"
    },
    {
      volume_name    = var.jellyfin_cache_vol
      container_path = "/cache"
    },
    {
      host_path      = local.media_path
      container_path = "/media"
    }
  ]

  # Add device mapping for hardware transcoding if available
  custom_labels = {
    "autoheal"                  = "true"
    "homepage.group"            = "Media Server"
    "homepage.name"             = "Jellyfin"
    "homepage.icon"             = "jellyfin.png"
    "homepage.href"             = "https://jellyfin.${var.domain_name}"
    "homepage.description"      = "Media Server"
    "homepage.widget.type"      = "jellyfin"
    "homepage.widget.url"       = "https://jellyfin.${var.domain_name}"
    "homepage.widget.key"       = "set-this-in-jellyfin"
  }
}

# Radarr - Movie management
module "radarr" {
  source = "../service_template"

  service_name  = "radarr"
  image         = "linuxserver/radarr:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks

  web_port     = 7878
  port_mappings = [
    {
      internal = 7878
      external = 7878
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.radarr_config_vol
      container_path = "/config"
    },
    {
      host_path      = var.mergerfs_mount_path
      container_path = "/storage"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Media Management"
    "homepage.name"        = "Radarr"
    "homepage.icon"        = "radarr.png"
    "homepage.href"        = "https://radarr.${var.domain_name}"
    "homepage.description" = "Movie Management"
    "homepage.widget.type" = "radarr"
    "homepage.widget.url"  = "https://radarr.${var.domain_name}"
    "homepage.widget.key"  = "set-this-in-radarr"
  }
}

# Sonarr - TV Show management
module "sonarr" {
  source = "../service_template"

  service_name  = "sonarr"
  image         = "linuxserver/sonarr:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks

  web_port     = 8989
  port_mappings = [
    {
      internal = 8989
      external = 8989
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.sonarr_config_vol
      container_path = "/config"
    },
    {
      host_path      = var.mergerfs_mount_path
      container_path = "/storage"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Media Management"
    "homepage.name"        = "Sonarr"
    "homepage.icon"        = "sonarr.png"
    "homepage.href"        = "https://sonarr.${var.domain_name}"
    "homepage.description" = "TV Show Management"
    "homepage.widget.type" = "sonarr"
    "homepage.widget.url"  = "https://sonarr.${var.domain_name}"
    "homepage.widget.key"  = "set-this-in-sonarr"
  }
}

# Prowlarr - Indexer management
module "prowlarr" {
  source = "../service_template"

  service_name  = "prowlarr"
  image         = "linuxserver/prowlarr:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks

  web_port     = 9696
  port_mappings = [
    {
      internal = 9696
      external = 9696
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.prowlarr_config_vol
      container_path = "/config"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Media Management"
    "homepage.name"        = "Prowlarr"
    "homepage.icon"        = "prowlarr.png"
    "homepage.href"        = "https://prowlarr.${var.domain_name}"
    "homepage.description" = "Indexer Management"
  }
}

# qBittorrent - Download client
module "qbittorrent" {
  source = "../service_template"

  service_name  = "qbittorrent"
  image         = "linuxserver/qbittorrent:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks

  web_port     = 8099
  port_mappings = [
    {
      internal = 8099
      external = 8099
    },
    {
      internal = 6881
      external = 6881
    },
    {
      internal = 6881
      external = 6881
      protocol = "udp"
    }
  ]

  custom_env = [
    "WEBUI_PORT=8099"
  ]

  volume_mappings = [
    {
      volume_name    = var.qbittorrent_config_vol
      container_path = "/config"
    },
    {
      host_path      = "${var.mergerfs_mount_path}/downloads"
      container_path = "/storage/downloads"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Media Management"
    "homepage.name"        = "qBittorrent"
    "homepage.icon"        = "qbittorrent.png"
    "homepage.href"        = "https://qbittorrent.${var.domain_name}"
    "homepage.description" = "Download Client"
  }
}

# Bazarr - Subtitle management
module "bazarr" {
  source = "../service_template"

  service_name  = "bazarr"
  image         = "linuxserver/bazarr:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks

  web_port     = 6767
  port_mappings = [
    {
      internal = 6767
      external = 6767
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.bazarr_config_vol
      container_path = "/config"
    },
    {
      host_path      = var.mergerfs_mount_path
      container_path = "/storage"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Media Management"
    "homepage.name"        = "Bazarr"
    "homepage.icon"        = "bazarr.png"
    "homepage.href"        = "https://bazarr.${var.domain_name}"
    "homepage.description" = "Subtitle Management"
  }
}

# Seerr - Media request management
module "seerr" {
  source = "../service_template"

  service_name  = "seerr"
  image         = "ghcr.io/seerr-team/seerr:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks
  init          = true

  web_port     = 5055
  port_mappings = [
    {
      internal = 5055
      external = 5055
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.seerr_config_vol
      container_path = "/app/config"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Media Management"
    "homepage.name"        = "Seerr"
    "homepage.icon"        = "overseerr.png"
    "homepage.href"        = "https://seerr.${var.domain_name}"
    "homepage.description" = "Media Requests"
  }
}

# Byparr - Cloudflare bypass service
module "byparr" {
  source = "../service_template"

  service_name  = "byparr"
  image         = "ghcr.io/thephaseless/byparr:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks

  web_port     = 8191
  port_mappings = [
    {
      internal = 8191
      external = 8191
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.byparr_config_vol
      container_path = "/config"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Media Management"
    "homepage.name"        = "Byparr"
    "homepage.icon"        = "byparr.png"
    "homepage.href"        = "https://byparr.${var.domain_name}"
    "homepage.description" = "Cloudflare Bypass Service"
  }
}