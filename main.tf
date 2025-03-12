terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
  }
}

# Variables
variable "ssh_host" {
  description = "CoreOS machine hostname or IP"
  type        = string
}

variable "ssh_user" {
  description = "SSH username for CoreOS machine"
  type        = string
  default     = "core"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "domain_name" {
  description = "Base domain name for Traefik routing"
  default     = "homelab.local"
}

variable "timezone" {
  description = "Local timezone for containers"
  default     = "Asia/Kolkata"
}

variable "mergerfs_mount_path" {
  description = "Path where mergerfs will mount the combined storage"
  default     = "/mnt/mergerfs"
}

variable "storage_disks" {
  description = "List of disk UUIDs to include in mergerfs"
  type        = list(string)
  default     = []  # Empty default, should be set in terraform.tfvars
}

variable "storage_mount_base" {
  description = "Base path where individual disks will be mounted"
  default     = "/mnt/disks"
}

variable "plex_claim" {
  description = "Plex claim token from https://plex.tv/claim"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tailscale_auth_key" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}

# Configure the Docker provider to use SSH
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

# Create Docker networks
resource "docker_network" "traefik_net" {
  name = "traefik_net"
}

resource "docker_network" "media_net" {
  name = "media_net"
}

# Create Docker volumes
resource "docker_volume" "plex_config" { name = "plex_config" }
resource "docker_volume" "plex_transcode" { name = "plex_transcode" }
resource "docker_volume" "radarr_config" { name = "radarr_config" }
resource "docker_volume" "sonarr_config" { name = "sonarr_config" }
resource "docker_volume" "prowlarr_config" { name = "prowlarr_config" }
resource "docker_volume" "qbittorrent_config" { name = "qbittorrent_config" }
resource "docker_volume" "hyperhdr_config" { name = "hyperhdr_config" }
resource "docker_volume" "homeassistant_config" { name = "homeassistant_config" }
resource "docker_volume" "traefik_config" { name = "traefik_config" }
resource "docker_volume" "traefik_acme" { name = "traefik_acme" }
resource "docker_volume" "tailscale_data" { name = "tailscale_data" }
resource "docker_volume" "portainer_data" { name = "portainer_data" }
resource "docker_volume" "overseerr_config" { name = "overseerr_config" }

# Setup disk mounting with UUIDs
resource "null_resource" "setup_disk_mounts" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Create base directories
      "sudo mkdir -p ${var.storage_mount_base}",
      "sudo mkdir -p ${var.mergerfs_mount_path}",

      # Generate fstab entries for UUID-based mounting
      "for uuid in ${join(" ", var.storage_disks)}; do",
      "  disk_name=$uuid",
      "  mount_path=${var.storage_mount_base}/$disk_name",
      "  sudo mkdir -p $mount_path",
      "  if ! grep -q $uuid /etc/fstab; then",
      "    echo \"UUID=$uuid $mount_path xfs defaults 0 2\" | sudo tee -a /etc/fstab",
      "  fi",
      "done",

      # Mount all disks from fstab
      "sudo mount -a || true",

      # Create required directories on each mounted disk
      "for uuid in ${join(" ", var.storage_disks)}; do",
      "  disk_name=$uuid",
      "  mount_path=${var.storage_mount_base}/$disk_name",
      "  sudo mkdir -p $mount_path/{media,downloads}/{movies,tv,music}",
      "  sudo mkdir -p $mount_path/downloads/{complete,incomplete}",
      "  sudo chmod -R 755 $mount_path",
      "done",

      # Create directory structure in mergerfs mount path (will be mounted by container)
      "sudo mkdir -p ${var.mergerfs_mount_path}/{media,downloads}/{movies,tv,music}",
      "sudo mkdir -p ${var.mergerfs_mount_path}/downloads/{complete,incomplete}",

      "sudo chown -R 1000:1000 ${var.mergerfs_mount_path}/media ${var.mergerfs_mount_path}/downloads",
      "sudo chmod -R 775 ${var.mergerfs_mount_path}/media ${var.mergerfs_mount_path}/downloads",

      # Add SELinux context for container access
      "if [ $(getenforce) = 'Enforcing' ]; then",
      "  sudo chcon -R -t container_file_t ${var.mergerfs_mount_path}",
      "  for uuid in ${join(" ", var.storage_disks)}; do",
      "    disk_name=$uuid",
      "    mount_path=${var.storage_mount_base}/$disk_name",
      "    sudo chcon -R -t container_file_t $mount_path",
      "  done",
      "fi",
    ]
  }
}

# Add a socket proxy container
resource "docker_container" "socket_proxy" {
  name  = "socket-proxy"
  image = "tecnativa/docker-socket-proxy:latest"
  restart = "unless-stopped"
  privileged = true

  env = [
    "CONTAINERS=1",
    "NETWORKS=1",
    "SERVICES=1",
    "TASKS=1"
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

# Use MergerFS in a container
resource "docker_container" "mergerfs" {
  name    = "mergerfs"
  image   = "hvalev/mergerfs:2.40.2.1"
  restart = "unless-stopped"
  privileged = true

  # Command to run mergerfs
  # Format: mergerfs [options] <srcmounts> <destmount>
  command = [
    "-o",
    "defaults,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=mfs,umask=022,uid=1000,gid=1000,permissions",
    "/mnt/disks",
    "${var.mergerfs_mount_path}"
  ]

  # Mount the storage directory and mergerfs target
  volumes {
    host_path      = var.storage_mount_base
    container_path = "/mnt/disks"
  }
  volumes {
    host_path      = var.mergerfs_mount_path
    container_path = var.mergerfs_mount_path
  }

  # Ensure fuse is available
  volumes {
    host_path      = "/dev/fuse"
    container_path = "/dev/fuse"
  }

  # Add host networking to ensure proper access
  network_mode = "host"

  # Add security options for FUSE
  security_opts = ["apparmor:unconfined"]
  capabilities {
    add = ["SYS_ADMIN"]
  }

  depends_on = [null_resource.setup_disk_mounts]
}
resource "null_resource" "traefik_config" {

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/traefik_config/_data",
      "sudo cat > /tmp/traefik.yml << 'EOL'",
      "entryPoints:",
      "  web:",
      "    address: ':80'",
      "providers:",
      "  docker:",
      "    endpoint: 'tcp://socket-proxy:2375'",
      "    exposedByDefault: false",
      "    network: traefik_net",
      "api:",
      "  dashboard: true",
      "  insecure: true",
      "EOL",
      "sudo cp /tmp/traefik.yml /var/lib/docker/volumes/traefik_config/_data/",
      "sudo chmod 644 /var/lib/docker/volumes/traefik_config/_data/traefik.yml",
      "rm /tmp/traefik.yml"
    ]
  }
}

# Traefik
resource "docker_container" "traefik" {
  name  = "traefik"
  image = "traefik:v2.10"
  restart = "unless-stopped"
  user = "0:0"

  privileged = true


  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 8080
    external = 8080
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
  volumes {
    volume_name    = docker_volume.traefik_config.name
    container_path = "/etc/traefik"
  }
  volumes {
    volume_name    = docker_volume.traefik_acme.name
    container_path = "/acme"
  }

  networks_advanced {
    name = docker_network.traefik_net.name
  }

  # Add a healthcheck to verify Traefik is running properly
  healthcheck {
    test         = ["CMD", "wget", "--spider", "http://localhost:8080/api/rawdata"]
    interval     = "10s"
    timeout      = "3s"
    start_period = "5s"
    retries      = 3
  }

  # Add a command to explicitly specify the config file location
  command = [
    "--configFile=/etc/traefik/traefik.yml"
  ]

  depends_on = [null_resource.traefik_config, docker_network.traefik_net]
}

# Tailscale
resource "docker_container" "tailscale" {
  name  = "tailscale"
  image = "tailscale/tailscale:latest"
  restart = "unless-stopped"
  network_mode = "host"
  privileged   = true

  env = [
    "TS_AUTH_KEY=${var.tailscale_auth_key}",
    "TS_STATE_DIR=/var/lib/tailscale"
  ]

  volumes {
    volume_name    = docker_volume.tailscale_data.name
    container_path = "/var/lib/tailscale"
  }
  volumes {
    host_path      = "/dev/net/tun"
    container_path = "/dev/net/tun"
  }
}

# Plex
resource "docker_container" "plex" {
  name  = "plex"
  image = "plexinc/pms-docker:latest"
  restart = "unless-stopped"


  env = [
    "TZ=${var.timezone}",
    "PLEX_UID=1000",
    "PLEX_GID=1000",
    "PLEX_CLAIM=${var.plex_claim}"
  ]



  ports {
    internal = 32400
    external = 32400
  }

  volumes {
    volume_name    = docker_volume.plex_config.name
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.plex_transcode.name
    container_path = "/transcode"
  }
  volumes {
    host_path      = "${var.mergerfs_mount_path}/media"
    container_path = "/data"
  }

  networks_advanced {
    name = docker_network.media_net.name
  }
  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.plex.rule"
    value = "Host(`plex.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.plex.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.plex.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.plex.loadbalancer.server.port"
    value = "32400"
  }

  depends_on = [docker_container.mergerfs, docker_network.media_net]
}

# Radarr
resource "docker_container" "radarr" {
  name  = "radarr"
  image = "linuxserver/radarr:latest"
  restart = "unless-stopped"


  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}"
  ]

  ports {
    internal = 7878
    external = 7878
  }

  volumes {
    volume_name    = docker_volume.radarr_config.name
    container_path = "/config"
  }
  volumes {
    host_path      = "${var.mergerfs_mount_path}/"
    container_path = "/storage"
  }

  networks_advanced {
    name = docker_network.media_net.name
  }
  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.radarr.rule"
    value = "Host(`radarr.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.radarr.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.radarr.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.radarr.loadbalancer.server.port"
    value = "7878"
  }

  depends_on = [docker_container.mergerfs, docker_network.media_net]
}

# Sonarr
resource "docker_container" "sonarr" {
  name  = "sonarr"
  image = "linuxserver/sonarr:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}"
  ]

  ports  {
    internal = 8989
    external = 8989
  }

  volumes {
    volume_name    = docker_volume.sonarr_config.name
    container_path = "/config"
  }
  volumes {
    host_path      = "${var.mergerfs_mount_path}/"
    container_path = "/storage"
  }

  networks_advanced {
    name = docker_network.media_net.name
  }
  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.sonarr.rule"
    value = "Host(`sonarr.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.sonarr.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.sonarr.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.sonarr.loadbalancer.server.port"
    value = "8989"
  }

  depends_on = [docker_container.mergerfs, docker_network.media_net]
}

# Prowlarr
resource "docker_container" "prowlarr" {
  name  = "prowlarr"
  image = "linuxserver/prowlarr:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}"
  ]

  ports  {
    internal = 9696
    external = 9696
  }

  volumes {
    volume_name    = docker_volume.prowlarr_config.name
    container_path = "/config"
  }

  networks_advanced {
    name = docker_network.media_net.name
  }
  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.prowlarr.rule"
    value = "Host(`prowlarr.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.prowlarr.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.prowlarr.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.prowlarr.loadbalancer.server.port"
    value = "9696"
  }

  depends_on = [docker_network.media_net]
}

# Add Docker volume for Bazarr
resource "docker_volume" "bazarr_config" { name = "bazarr_config" }

# Bazarr container
resource "docker_container" "bazarr" {
  name  = "bazarr"
  image = "linuxserver/bazarr:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}"
  ]

  ports {
    internal = 6767
    external = 6767
  }

  volumes {
    volume_name    = docker_volume.bazarr_config.name
    container_path = "/config"
  }
  volumes {
    host_path      = "${var.mergerfs_mount_path}/"
    container_path = "/storage"
  }

  networks_advanced {
    name = docker_network.media_net.name
  }
  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.bazarr.rule"
    value = "Host(`bazarr.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.bazarr.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.bazarr.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.bazarr.loadbalancer.server.port"
    value = "6767"
  }

  depends_on = [docker_container.mergerfs, docker_network.media_net, docker_container.sonarr, docker_container.radarr]
}

# qBittorrent
resource "docker_container" "qbittorrent" {
  name  = "qbittorrent"
  image = "linuxserver/qbittorrent:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}",
    "WEBUI_PORT=8099"
  ]

  ports {
    internal = 8099
    external = 8099
  }
  ports {
    internal = 6881
    external = 6881
  }
  ports {
    internal = 6881
    external = 6881
    protocol = "udp"
  }

  volumes {
    volume_name    = docker_volume.qbittorrent_config.name
    container_path = "/config"
  }
  volumes {
    host_path      = "${var.mergerfs_mount_path}/downloads"
    container_path = "/storage/downloads"
  }

  networks_advanced {
    name = docker_network.media_net.name
  }
  
  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.qbittorrent.rule"
    value = "Host(`qbittorrent.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.qbittorrent.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.qbittorrent.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.qbittorrent.loadbalancer.server.port"
    value = "8080"
  }

  depends_on = [docker_container.mergerfs, docker_network.media_net]
}

# HomeAssistant
resource "docker_container" "homeassistant" {
  name  = "homeassistant"
  image = "homeassistant/home-assistant:latest"
  restart = "unless-stopped"

  env = [
    "TZ=${var.timezone}"
  ]

  ports {
    internal = 8123
    external = 8123
  }

  volumes {
    volume_name    = docker_volume.homeassistant_config.name
    container_path = "/config"
  }

  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.homeassistant.rule"
    value = "Host(`homeassistant.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.homeassistant.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.homeassistant.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.homeassistant.loadbalancer.server.port"
    value = "8123"
  }

  depends_on = [docker_network.traefik_net]
}

# Portainer
resource "docker_container" "portainer" {
  name  = "portainer"
  image = "portainer/portainer-ce:lts"
  restart = "unless-stopped"

  ports {
    internal = 9000
    external = 9000
  }
  ports {
    internal = 9443
    external = 9443
  }

  volumes {
    volume_name    = docker_volume.portainer_data.name
    container_path = "/data"
  }
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.portainer.rule"
    value = "Host(`portainer.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.portainer.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.portainer.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.portainer.loadbalancer.server.port"
    value = "9000"
  }

  depends_on = [docker_network.traefik_net]
}

# First, create a place for the Dockerfile that's accessible to both SSH and Docker
resource "null_resource" "prepare_hyperhdr_context" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Create build directory in a location accessible to docker
      "sudo mkdir -p /opt/docker-builds/hyperhdr",
      "sudo chmod 777 /opt/docker-builds/hyperhdr",

      # Create the Dockerfile
      "cat > /opt/docker-builds/hyperhdr/Dockerfile << 'EOL'",
      "FROM ubuntu:jammy",
      "ENV DEBIAN_FRONTEND=noninteractive",
      "RUN apt-get update && \\",
      "apt-get install -y --no-install-recommends wget ca-certificates && \\",
      "rm -rf /var/lib/apt/lists/*",
      "RUN wget -qP /tmp https://github.com/awawa-dev/HyperHDR/releases/download/v21.0.0.0beta2/HyperHDR-21.0.0.0.jammy.beta2-x86_64.deb && \\",
      "apt-get update && \\",
      "apt-get install -y --no-install-recommends /tmp/HyperHDR-21.0.0.0.jammy.beta2-x86_64.deb && \\",
      "rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*",
      "RUN mkdir -p /config && chmod -R 777 /config",
      "EXPOSE 8090 8092 19400 19444 19445",
      "ENTRYPOINT [\"hyperhdr\", \"-v\", \"-u=/config\"]",
      "EOL",

      # Verify the file is created
      "ls -la /opt/docker-builds/hyperhdr/",
      "cat /opt/docker-builds/hyperhdr/Dockerfile"
    ]
  }
}

# Now use a simpler command-line approach to build the image
resource "null_resource" "build_hyperhdr_image" {
  depends_on = [null_resource.prepare_hyperhdr_context]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Build the image using the created Dockerfile
      "cd /opt/docker-builds/hyperhdr && sudo docker build -t custom-hyperhdr:latest .",

      # Verify the image was created
      "sudo docker images | grep custom-hyperhdr"
    ]
  }
}

# Then use the pre-built image in your container
resource "docker_container" "hyperhdr" {
  name  = "hyperhdr"
  image = "custom-hyperhdr:latest"
  restart = "unless-stopped"
  privileged = true
  network_mode = "host"

  volumes {
    volume_name    = docker_volume.hyperhdr_config.name
    container_path = "/config"
  }

  depends_on = [null_resource.build_hyperhdr_image]
}



# Overseerr container
resource "docker_container" "overseerr" {
  name  = "overseerr"
  image = "sctx/overseerr:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}"
  ]

  ports {
    internal = 5055
    external = 5055
  }

  volumes {
    volume_name    = docker_volume.overseerr_config.name
    container_path = "/app/config"
  }

  networks_advanced {
    name = docker_network.media_net.name
  }
  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.overseerr.rule"
    value = "Host(`overseerr.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.overseerr.entrypoints"
    value = "web"
  }
  # labels {
  #   label = "traefik.http.routers.overseerr.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.overseerr.loadbalancer.server.port"
    value = "5055"
  }

  depends_on = [docker_network.media_net, docker_container.plex]
}


# Create Docker volume for Jellyfin
resource "docker_volume" "jellyfin_config" { name = "jellyfin_config" }
resource "docker_volume" "jellyfin_cache" { name = "jellyfin_cache" }

# Jellyfin container
resource "docker_container" "jellyfin" {
  name  = "jellyfin"
  image = "jellyfin/jellyfin:latest"
  restart = "unless-stopped"

  # Disable SELinux labeling to prevent permission issues
  security_opts = ["label:disable"]

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}"
  ]

  ports {
    internal = 8096
    external = 8096
  }

  # Hardware acceleration - uncomment if you have compatible hardware
  devices {
    host_path = "/dev/dri"
    container_path = "/dev/dri"
  }

  volumes {
    volume_name    = docker_volume.jellyfin_config.name
    container_path = "/config"
  }
  volumes {
    volume_name    = docker_volume.jellyfin_cache.name
    container_path = "/cache"
  }
  volumes {
    host_path      = "${var.mergerfs_mount_path}/media"
    container_path = "/media"
    read_only      = false
  }

  networks_advanced {
    name = docker_network.media_net.name
  }
  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.jellyfin.rule"
    value = "Host(`jellyfin.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.jellyfin.entrypoints"
    value = "web"
  }
  # Uncomment if you enable HTTPS with Traefik
  # labels {
  #   label = "traefik.http.routers.jellyfin.tls"
  #   value = "true"
  # }
  labels {
    label = "traefik.http.services.jellyfin.loadbalancer.server.port"
    value = "8096"
  }

  depends_on = [docker_container.mergerfs, docker_network.media_net]
}

# Update the output to include Jellyfin
output "homelab_services" {
  value = {
    plex          = "https://plex.${var.domain_name}"
    radarr        = "https://radarr.${var.domain_name}"
    sonarr        = "https://sonarr.${var.domain_name}"
    prowlarr      = "https://prowlarr.${var.domain_name}"
    qbittorrent   = "https://qbittorrent.${var.domain_name}"
    homeassistant = "https://homeassistant.${var.domain_name}"
    hyperhdr      = "Access via IP: ${var.ssh_host}:8090"
    portainer     = "https://portainer.${var.domain_name}"
    overseerr     = "https://overseerr.${var.domain_name}"
    jellyfin      = "https://jellyfin.${var.domain_name}"
  }
}

output "plex_claim_info" {
  value = "Get your Plex claim token from https://plex.tv/claim (valid for 4 minutes after generation)"
}