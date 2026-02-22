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