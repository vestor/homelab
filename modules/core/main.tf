terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}
# Create Docker networks
resource "docker_network" "traefik_net" {
  name = "traefik_net"
}

resource "docker_network" "media_net" {
  name = "media_net"
}

# Create Docker volumes - centralized volume creation
resource "docker_volume" "volumes" {
  for_each = toset([
    # Media services
    "radarr_config", "sonarr_config", "prowlarr_config",
    "qbittorrent_config", "jellyfin_config", "jellyfin_cache",
    "bazarr_config", "jellyseerr_config", "byparr_config",

    # Home automation
    "hyperhdr_config", "homeassistant_config",

    # Networking
    "traefik_config", "traefik_acme", "tailscale_data",

    # Dashboards and management
    "homepage_config", "watchtower_config", "whatsup_docker_data"
  ])

  name = each.key
}

# Socket proxy for secure Docker API access
resource "docker_container" "socket_proxy" {
  name       = "socket-proxy"
  image      = "tecnativa/docker-socket-proxy:latest"
  restart    = "unless-stopped"
  privileged = true

  ports {
    internal = 2375
    external = 2375
  }

  env = [
    "CONTAINERS=1",  # Allow listing containers
    "NETWORKS=1",    # Allow network operations
    "SERVICES=1",    # Allow service operations
    "TASKS=1",       # Allow task operations
    "IMAGES=1",      # Allow image operations - needed by Watchtower
    "VOLUMES=1",     # Allow volume operations
    "VERSION=1",     # Allow version check
    "AUTH=1",        # Allow authentication operations
    "DISTRIBUTION=1", # Allow distribution operations
    "POST=1",        # Allow POST operations (needed for updates)
    "BUILD=1",       # Allow build operations
    "COMMIT=1",      # Allow commit operations
    "CONFIGS=1",     # Allow config operations
    "EXEC=1",        # Allow exec operations
    "NODES=1"        # Allow node operations
  ]

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.traefik_net.name
  }
}