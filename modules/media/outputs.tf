# Compile service URLs for all media services
output "media_service_urls" {
  description = "URLs for all media services"
  value = {
    radarr      = module.radarr.service_url
    sonarr      = module.sonarr.service_url
    prowlarr    = module.prowlarr.service_url
    qbittorrent = module.qbittorrent.service_url
    jellyfin    = module.jellyfin.service_url
    bazarr      = module.bazarr.service_url
    seerr       = module.seerr.service_url
    byparr      = module.byparr.service_url
  }
}

# Container names for referencing
output "container_names" {
  description = "Names of deployed media service containers"
  value = {
    radarr      = module.radarr.container_name
    sonarr      = module.sonarr.container_name
    prowlarr    = module.prowlarr.container_name
    qbittorrent = module.qbittorrent.container_name
    jellyfin    = module.jellyfin.container_name
    bazarr      = module.bazarr.container_name
    seerr       = module.seerr.container_name
    byparr      = module.byparr.container_name
  }
}

output "glance_services" {
  description = "Service definitions for Glance dashboard"
  value = [
    {
      name         = "Jellyfin"
      group        = "Media"
      url          = "https://jellyfin.${var.domain_name}"
      icon         = "si:jellyfin"
      internal_url = "http://jellyfin:8096"
      github_repo  = "jellyfin/jellyfin"
    },
    {
      name         = "Seerr"
      group        = "Media"
      url          = "https://seerr.${var.domain_name}"
      icon         = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/overseerr.svg"
      internal_url = "http://seerr:5055"
      github_repo  = "sct/overseerr"
    },
    {
      name         = "Sonarr"
      group        = "Media Management"
      url          = "https://sonarr.${var.domain_name}"
      icon         = "si:sonarr"
      internal_url = "http://sonarr:8989"
      github_repo  = "Sonarr/Sonarr"
    },
    {
      name         = "Radarr"
      group        = "Media Management"
      url          = "https://radarr.${var.domain_name}"
      icon         = "si:radarr"
      internal_url = "http://radarr:7878"
      github_repo  = "Radarr/Radarr"
    },
    {
      name         = "Bazarr"
      group        = "Media Management"
      url          = "https://bazarr.${var.domain_name}"
      icon         = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/bazarr.svg"
      internal_url = "http://bazarr:6767"
      github_repo  = ""
    },
    {
      name         = "Prowlarr"
      group        = "Media Management"
      url          = "https://prowlarr.${var.domain_name}"
      icon         = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/prowlarr.svg"
      internal_url = "http://prowlarr:9696"
      github_repo  = "Prowlarr/Prowlarr"
    },
    {
      name         = "qBittorrent"
      group        = "Media Management"
      url          = "https://qbittorrent.${var.domain_name}"
      icon         = "si:qbittorrent"
      internal_url = "http://qbittorrent:8099"
      github_repo  = ""
    },
    {
      name         = "Byparr"
      group        = "Media Management"
      url          = "https://byparr.${var.domain_name}"
      icon         = ""
      internal_url = ""
      github_repo  = ""
    },
  ]
}
