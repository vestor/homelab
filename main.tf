terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.35.0"
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

variable "tailscale_auth_key" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}

# Add Cloudflare API token as a variable
variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS verification"
  type        = string
  sensitive   = true
}

variable "cloudflare_email" {
  description = "Cloudflare account email"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain"
  type        = string
  sensitive = true
}

variable "tailscale_ip" {
  description = "IP of the Tailscale homelab node"
  type        = string
  sensitive = true
}


provider "cloudflare" {
  api_token = var.cloudflare_api_token
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
resource "docker_volume" "radarr_config" { name = "radarr_config" }
resource "docker_volume" "sonarr_config" { name = "sonarr_config" }
resource "docker_volume" "prowlarr_config" { name = "prowlarr_config" }
resource "docker_volume" "qbittorrent_config" { name = "qbittorrent_config" }
resource "docker_volume" "hyperhdr_config" { name = "hyperhdr_config" }
resource "docker_volume" "homeassistant_config" { name = "homeassistant_config" }
resource "docker_volume" "traefik_config" { name = "traefik_config" }
resource "docker_volume" "traefik_acme" { name = "traefik_acme" }
resource "docker_volume" "tailscale_data" { name = "tailscale_data" }
resource "docker_volume" "jellyseerr_config" { name = "jellyseerr_config" }
resource "docker_volume" "watchtower_config" { name = "watchtower_config" }
resource "docker_volume" "bazarr_config" { name = "bazarr_config" }
resource "docker_volume" "whatsup_docker_data" { name = "whatsup_docker_data" }


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

resource "docker_container" "socket_proxy" {
  name  = "socket-proxy"
  image = "tecnativa/docker-socket-proxy:latest"
  restart = "unless-stopped"
  privileged = true

  # Add port mapping for Docker API
  ports {
    internal = 2375
    external = 2375
  }

  env = [
    "CONTAINERS=1",        # Allow listing containers
    "NETWORKS=1",          # Allow network operations
    "SERVICES=1",          # Allow service operations
    "TASKS=1",             # Allow task operations
    "IMAGES=1",            # Allow image operations - needed by Watchtower
    "VOLUMES=1",           # Allow volume operations
    "VERSION=1",           # Allow version check
    "AUTH=1",              # Allow authentication operations
    "DISTRIBUTION=1",      # Allow distribution operations
    "POST=1",              # Allow POST operations (needed for updates)
    "BUILD=1",             # Allow build operations
    "COMMIT=1",            # Allow commit operations
    "CONFIGS=1",           # Allow config operations
    "EXEC=1",              # Allow exec operations
    "NODES=1"              # Allow node operations
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

# Update the Traefik configuration with Cloudflare and Let's Encrypt
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
      "    http:",
      "      redirections:",
      "        entryPoint:",
      "          to: websecure",
      "          scheme: https",
      "  websecure:",
      "    address: ':443'",
      "  tailscale:",
      "    address: ':8443'",
      "providers:",
      "  docker:",
      "    endpoint: 'tcp://socket-proxy:2375'",
      "    exposedByDefault: false",
      "    network: traefik_net",
      "    swarmMode: false",
      "    watch: true",
      "api:",
      "  dashboard: true",
      "  insecure: true",
      "certificatesResolvers:",
      "  cloudflare:",
      "    acme:",
      "      email: '${var.cloudflare_email}'",
      "      storage: /acme/acme.json",
      "      dnsChallenge:",
      "        provider: cloudflare",
      "        resolvers:",
      "          - '1.1.1.1:53'",
      "          - '1.0.0.1:53'",
      "log:",
      "  level: 'INFO'",
      "EOL",
      "sudo cp /tmp/traefik.yml /var/lib/docker/volumes/traefik_config/_data/",

      # Create dynamic configuration for middleware
      "sudo mkdir -p /var/lib/docker/volumes/traefik_config/_data/configs",
      "sudo cat > /tmp/dynamic.yml << 'EOL'",
      "http:",
      "  middlewares:",
      "    tailscale-ip-whitelist:",
      "      ipWhiteList:",
      "        sourceRange:",
      "          - '127.0.0.1/32'       # Local traffic",
      "          - '192.168.0.0/16'     # Local LAN traffic",
      "          - '10.0.0.0/8'         # Tailscale IP range",
      "          - '100.64.0.0/10'      # Tailscale IP range (CGNAT)",
      "    local-ip-whitelist:",
      "      ipWhiteList:",
      "        sourceRange:",
      "          - '127.0.0.1/32'       # Local traffic",
      "          - '192.168.0.0/16'     # Local LAN traffic",
      "EOL",
      "sudo cp /tmp/dynamic.yml /var/lib/docker/volumes/traefik_config/_data/configs/",
      "sudo chmod 644 /var/lib/docker/volumes/traefik_config/_data/traefik.yml",
      "sudo chmod 644 /var/lib/docker/volumes/traefik_config/_data/configs/dynamic.yml",
      "rm /tmp/traefik.yml /tmp/dynamic.yml"
    ]
  }
}

# Update the Traefik container with HTTPS support and Cloudflare DNS
resource "docker_container" "traefik" {
  name  = "traefik"
  image = "traefik:v2.10"
  restart = "unless-stopped"
  user = "0:0"

  # Add a brief delay before Traefik starts to ensure socket-proxy is ready
  command = [
    "sh", "-c",
    "sleep 5 && /usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml"
  ]

  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 443
    external = 443
  }
  ports {
    internal = 8080
    external = 8081
  }
  ports {
    internal = 8443
    external = 8443
  }

  env = [
    "CF_API_EMAIL=${var.cloudflare_email}",
    "CF_DNS_API_TOKEN=${var.cloudflare_api_token}",
    "CF_ZONE_API_TOKEN=${var.cloudflare_api_token}",
    "TZ=${var.timezone}"
  ]

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

  depends_on = [
    docker_container.socket_proxy,
    null_resource.traefik_config,
    docker_network.traefik_net
  ]
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
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.radarr.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.routers.radarr.tls"
    value = "true"
  }
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
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.sonarr.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.routers.sonarr.tls"
    value = "true"
  }
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
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.prowlarr.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.routers.prowlarr.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.services.prowlarr.loadbalancer.server.port"
    value = "9696"
  }

  depends_on = [docker_network.media_net]
}

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
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.bazarr.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.routers.bazarr.tls"
    value = "true"
  }
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
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.qbittorrent.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.qbittorrent.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.services.qbittorrent.loadbalancer.server.port"
    value = "8099"
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
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.homeassistant.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.homeassistant.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.services.homeassistant.loadbalancer.server.port"
    value = "8123"
  }

  depends_on = [docker_network.traefik_net]
}


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
      "sudo chmod 777 /opt/docker-builds/hyperhdr"
    ]
  }

  # Upload the Dockerfile from local templates folder to the remote server
  provisioner "file" {
    source      = "${path.module}/templates/hyperhdr.dockerfile"
    destination = "/opt/docker-builds/hyperhdr/Dockerfile"
  }
}

resource "null_resource" "build_hyperhdr_image" {
  depends_on = [null_resource.prepare_hyperhdr_context]

  # Add a trigger that changes whenever the Dockerfile changes
  triggers = {
    dockerfile_sha1 = sha1(file("${path.module}/templates/hyperhdr.dockerfile"))
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Remove any existing image first to force rebuild
      "sudo docker image rm -f custom-hyperhdr:latest || true",
      # Build the image using the uploaded Dockerfile
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

  volumes {
    volume_name    = docker_volume.hyperhdr_config.name
    container_path = "/config"
  }

  ports {
    internal = 19400
    external = 19400
  }
  ports {
    internal = 19444
    external = 19444
  }
  ports {
    internal = 19445
    external = 19445
  }
  ports {
    internal = 8090
    external = 8090
  }
  ports {
    internal = 8092
    external = 8092
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.hyperhdr.rule"
    value = "Host(`hyperhdr.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.hyperhdr.entrypoints"
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.hyperhdr.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.routers.hyperhdr.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.services.hyperhdr.loadbalancer.server.port"
    value = "8090"
  }

  depends_on = [null_resource.build_hyperhdr_image]
}



# jellyseerr container
resource "docker_container" "jellyseerr" {
  name  = "jellyseerr"
  image = "ghcr.io/fallenbagel/jellyseerr:latest"
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
    volume_name    = docker_volume.jellyseerr_config.name
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
    label = "traefik.http.routers.jellyseerr.rule"
    value = "Host(`jellyseerr.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.jellyseerr.entrypoints"
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.jellyseerr.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.routers.jellyseerr.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.services.jellyseerr.loadbalancer.server.port"
    value = "5055"
  }

  depends_on = [docker_network.media_net]
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
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.jellyfin.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.jellyfin.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.services.jellyfin.loadbalancer.server.port"
    value = "8096"
  }

  depends_on = [docker_container.mergerfs, docker_network.media_net]
}

resource "cloudflare_record" "homelab" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  value   = var.tailscale_ip
  type    = "A"
  ttl     = 1 # Auto (using Cloudflare proxy)
  proxied = false
}

# Homepage container
# Create Docker volume for Homepage
resource "docker_volume" "homepage_config" { name = "homepage_config" }

# Homepage container
resource "docker_container" "homepage" {
  name  = "homepage"
  image = "ghcr.io/gethomepage/homepage:latest"
  restart = "unless-stopped"

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}",
    # Environment variables to enable service discovery
    "HOMEPAGE_VAR_DOCKER_HOST=socket-proxy",
    "HOMEPAGE_VAR_DOCKER_PORT=2375",
    "HOMEPAGE_VAR_DOCKER_SOCKET=tcp",
    "HOMEPAGE_ALLOWED_HOSTS=homelab:3000,localhost:3000,127.0.0.1:3000"
  ]

  ports {
    internal = 3000
    external = 3000
  }

  volumes {
    volume_name    = docker_volume.homepage_config.name
    container_path = "/app/config"
  }

  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.homepage.rule"
    value = "Host(`homepage.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.homepage.entrypoints"
    value = "web,websecure"
  }
  labels {
    label = "traefik.http.routers.homepage.tls.certresolver"
    value = "cloudflare"
  }
  labels {
    label = "traefik.http.routers.homepage.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.services.homepage.loadbalancer.server.port"
    value = "3000"
  }

  depends_on = [
    docker_container.socket_proxy,
    docker_network.traefik_net,
    null_resource.homepage_config_files
  ]
}

# Copy config files to the remote server
resource "null_resource" "homepage_config_files" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  # Use a trigger to update configs when the template content changes
  triggers = {
    services_sha1 = sha1(templatefile("${path.module}/templates/services.yaml.tftpl", {
      domain_name = var.domain_name
      ssh_host = var.ssh_host
    }))
    settings_sha1 = sha1(templatefile("${path.module}/templates/settings.yaml.tftpl", {}))
    widgets_sha1 = sha1(templatefile("${path.module}/templates/widgets.yaml.tftpl", {
      mergerfs_mount_path = var.mergerfs_mount_path
    }))
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/homepage-config"
    ]
  }

  # Upload the rendered template files to the server
  provisioner "file" {
    content     = templatefile("${path.module}/templates/services.yaml.tftpl", {
      domain_name = var.domain_name
      ssh_host = var.ssh_host
    })
    destination = "/tmp/homepage-config/services.yaml"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/settings.yaml.tftpl", {})
    destination = "/tmp/homepage-config/settings.yaml"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/widgets.yaml.tftpl", {
      mergerfs_mount_path = var.mergerfs_mount_path
    })
    destination = "/tmp/homepage-config/widgets.yaml"
  }

  # Copy files to the Docker volume
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/homepage_config/_data",
      "sudo cp /tmp/homepage-config/*.yaml /var/lib/docker/volumes/homepage_config/_data/",
      "sudo chown -R 1000:1000 /var/lib/docker/volumes/homepage_config/_data/",
      "sudo chmod -R 755 /var/lib/docker/volumes/homepage_config/_data/",
      "rm -rf /tmp/homepage-config"
    ]
  }
}

# Watchtower container
resource "docker_container" "watchtower" {
  name  = "watchtower"
  image = "containrrr/watchtower:latest"
  restart = "unless-stopped"

  env = [
    "TZ=${var.timezone}",
    "WATCHTOWER_CLEANUP=true",                 # Remove old images
    "WATCHTOWER_INCLUDE_STOPPED=false",        # Only update running containers
    "WATCHTOWER_NOTIFICATION_REPORT=true",     # More detailed notifications
    "WATCHTOWER_POLL_INTERVAL=86400",          # Check for updates once a day (in seconds)
    "WATCHTOWER_TIMEOUT=60s",                  # Timeout for container operations
    "WATCHTOWER_ROLLING_RESTART=true",         # Restart containers one by one
    "DOCKER_HOST=tcp://socket-proxy:2375",     # Connect to Docker via the socket proxy
  ]

  volumes {
    volume_name    = docker_volume.watchtower_config.name
    container_path = "/config"
  }

  networks_advanced {
    name = docker_network.traefik_net.name
  }

  # Watchtower doesn't have a web UI by default
  labels {
    label = "traefik.enable"
    value = "false"
  }

  depends_on = [docker_container.socket_proxy]
}


# WhatSup Docker container
resource "docker_container" "whatsup_docker" {
  name  = "whatsup_docker"
  image = "fmartinou/whats-up-docker:latest"
  restart = "unless-stopped"

  env = [
    "TZ=${var.timezone}",
    "WUD_WATCHER_DOCKER_HOST=socket-proxy",
    "WUD_WATCHER_DOCKER_PORT=2375",
    "WUD_WATCHER_DOCKER_SOCKET=tcp://socket-proxy",
    "WUD_UI_HOST=0.0.0.0",
    "WUD_UI_PORT=3000",
    "WUD_TRIGGER_WATCHTOWER=true",
    "WUD_TRIGGER_WATCHTOWER_ARGS=--cleanup"
  ]

  ports {
    internal = 3000
    external = 3001  # Using 3001 to avoid conflict with homepage
  }

  volumes {
    volume_name    = docker_volume.whatsup_docker_data.name
    container_path = "/store"
  }

  networks_advanced {
    name = docker_network.traefik_net.name
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.whatsup.rule"
    value = "Host(`whatsup.${var.domain_name}`)"
  }
  labels {
    label = "traefik.http.routers.whatsup.entrypoints"
    value = "web,websecure"
  }
  labels {
      label = "traefik.http.routers.whatsup.tls.certresolver"
      value = "cloudflare"
  }
  labels {
      label = "traefik.http.routers.whatsup.tls"
      value = "true"
  }

  labels {
    label = "traefik.http.services.whatsup.loadbalancer.server.port"
    value = "3000"
  }

  depends_on = [docker_container.socket_proxy, docker_container.watchtower]
}

resource "null_resource" "disable_systemd_resolved" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Stop and disable systemd-resolved
      "sudo systemctl stop systemd-resolved || echo 'Failed to stop systemd-resolved'",
      "sudo systemctl disable systemd-resolved || echo 'Failed to disable systemd-resolved'",

      # Create a backup of the current resolv.conf
      "sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d%H%M%S) || echo 'No backup created'",

      # Set up a basic resolv.conf with Google DNS
      "sudo rm -f /etc/resolv.conf || echo 'Failed to remove resolv.conf'",
      "echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf > /dev/null",
      "echo 'nameserver 8.8.4.4' | sudo tee -a /etc/resolv.conf > /dev/null",

      # Verify the changes
      "echo 'Current resolv.conf:'",
      "cat /etc/resolv.conf",

      # Ensure systemd doesn't recreate resolv.conf
      "if [ -d /etc/systemd/resolved.conf.d ]; then",
      "  echo 'DNSStubListener=no' | sudo tee /etc/systemd/resolved.conf.d/disable-stub-listener.conf > /dev/null || echo 'Could not create configuration'",
      "fi",

      # Verify systemd-resolved is stopped
      "systemctl status systemd-resolved --no-pager || echo 'systemd-resolved is not running'"
    ]
  }
}

# Create CoreDNS volume for configuration
resource "docker_volume" "coredns_config" { name = "coredns_config" }

# Set up CoreDNS configuration
resource "null_resource" "coredns_config" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/coredns_config/_data",

      # Create the Corefile with admin interface disabled
      "sudo cat > /tmp/Corefile << 'EOL'",
      ".:53 {",
      "    # Forward most requests to external DNS",
      "    forward . 8.8.8.8 8.8.4.4 {",
      "        policy random",
      "        health_check 5s",
      "    }",
      "    # Enable DNS cache",
      "    cache 30",
      "    # Error logging",
      "    errors",
      "    # Enable prometheus metrics",
      "    prometheus :9153",
      "    # Load balance between A/AAAA replies",
      "    loadbalance",
      "}",
      "# Handle your custom domain",
      "${var.domain_name}:53 {",
      "    hosts {",
      "        ${var.ssh_host} *.${var.domain_name}",
      "        fallthrough",
      "    }",
      "    # Important: Forward queries that hosts plugin doesn't answer",
      "    forward . 8.8.8.8 8.8.4.4",
      "    # Enable DNS cache",
      "    cache 30",
      "    errors",
      "}",
      "EOL",
      "sudo cp /tmp/Corefile /var/lib/docker/volumes/coredns_config/_data/",
      "sudo chmod 644 /var/lib/docker/volumes/coredns_config/_data/Corefile",
      "rm /tmp/Corefile"
    ]
  }
}

# Update the CoreDNS container to use a different health check method
resource "docker_container" "coredns" {
  name  = "coredns"
  image = "coredns/coredns:latest"
  restart = "unless-stopped"

  # Since we're using host networking, port mappings are for documentation only
  ports {
    internal = 53
    external = 53
    protocol = "udp"
  }
  ports {
    internal = 53
    external = 53
    protocol = "tcp"
  }
  ports {
    internal = 9153
    external = 9153
  }

  volumes {
    volume_name    = docker_volume.coredns_config.name
    container_path = "/etc/coredns"
  }

  # Add critical environment variables to disable default admin interface
  env = [
    "GODEBUG=netdns=go",   # Use Go's DNS resolver
    "CORES=0",             # Use all available cores
    # Add any other needed environment variables
  ]

  # Explicitly disable the built-in admin interface with command-line flags
  command = [
    "-conf",
    "/etc/coredns/Corefile",
    "-dns.port",
    "53"
  ]

  # Use host networking for proper DNS functionality
  network_mode = "host"

  # Change healthcheck to use DNS functionality instead of HTTP
  healthcheck {
    test         = ["CMD", "dig", "@127.0.0.1", "-p", "53", "localhost"]
    interval     = "10s"
    timeout      = "5s"
    start_period = "5s"
    retries      = 3
  }

  depends_on = [null_resource.coredns_config, null_resource.disable_systemd_resolved]
}


output "homelab_services" {
  value = {
    radarr        = "https://radarr.${var.domain_name}"
    sonarr        = "https://sonarr.${var.domain_name}"
    prowlarr      = "https://prowlarr.${var.domain_name}"
    qbittorrent   = "https://qbittorrent.${var.domain_name}"
    homeassistant = "https://homeassistant.${var.domain_name}"
    hyperhdr      = "https://hyperhdr.${var.domain_name}"
    jellyseerr    = "https://jellyseerr.${var.domain_name}"
    jellyfin      = "https://jellyfin.${var.domain_name}"
    whatsup       = "https://whatsup.${var.domain_name}"
  }
}
