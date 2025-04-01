# Homelab Infrastructure as Code

This repository contains Terraform configurations to deploy and manage a comprehensive homelab environment. The infrastructure is designed to run on a CoreOS machine using Docker containers with a focus on media management, home automation, and system monitoring.

## Features

- **Storage Management**: MergerFS for unified storage across multiple disks
- **Reverse Proxy**: Traefik for service routing with hostname-based access
- **Media Management**:
  - **Jellyfin**: Media server with transcoding capabilities
  - **Sonarr**: TV show management and automation
  - **Radarr**: Movie management and automation
  - **Bazarr**: Subtitle management for Sonarr and Radarr
  - **Prowlarr**: Indexer management for *arr applications
  - **qBittorrent**: Download client
  - **Jellyseerr**: Media request and management
- **Home Automation**:
  - **Home Assistant**: Smart home control and automation
  - **HyperHDR**: Ambient lighting control
- **System Management**:
  - **Tailscale**: Secure remote access
  - **Homepage**: Unified dashboard for system monitoring and service access
  - **Watchtower**: Automatic updates for Docker containers
  - **WhatSup Docker**: Docker container monitoring
  - **CoreDNS**: DNS server for local network

## Prerequisites

- A CoreOS or similar Linux machine with SSH access
- Docker installed on the target machine
- Terraform v1.0 or higher installed on your local machine
- SSH key access to the target machine

## Getting Started

1. Clone this repository
   ```
   git clone https://github.com/yourusername/homelab-infrastructure.git
   cd homelab-infrastructure
   ```

2. Create a `terraform.tfvars` file with your configuration:
   ```hcl
   ssh_host = "your-server-ip-or-hostname"
   ssh_user = "core"
   ssh_key_path = "~/.ssh/your_private_key"
   domain_name = "yourdomain.local"
   timezone = "Your/Timezone"
   storage_disks = ["uuid1", "uuid2"] # UUIDs of your storage disks
   tailscale_auth_key = "tskey-auth-xxxxxxxx" # Your Tailscale auth key
   cloudflare_api_token = "your-cloudflare-api-token"
   cloudflare_email = "your-cloudflare-email"
   ```

3. Initialize Terraform:
   ```
   terraform init
   ```

4. Validate and apply the configuration:
   ```
   terraform validate
   terraform plan
   terraform apply
   ```

## Service Access

After deployment, services will be available at the following URLs:

- Homepage Dashboard: https://homepage.yourdomain.local
- Jellyfin: https://jellyfin.yourdomain.local
- Sonarr: https://sonarr.yourdomain.local
- Radarr: https://radarr.yourdomain.local
- Bazarr: https://bazarr.yourdomain.local
- Prowlarr: https://prowlarr.yourdomain.local
- qBittorrent: https://qbittorrent.yourdomain.local
- Jellyseerr: https://jellyseerr.yourdomain.local
- HomeAssistant: https://homeassistant.yourdomain.local
- HyperHDR: Access via IP address on port 8090
- WhatSup Docker: https://whatsup.yourdomain.local

## Storage Configuration

The system uses MergerFS to combine multiple storage disks into a unified filesystem:

1. Individual disks are mounted at `/mnt/disks/{uuid}`
2. MergerFS combines these into a single mount at `/mnt/mergerfs`
3. Each disk gets standardized directories for media and downloads

## Management and Maintenance

### Adding New Disks

To add new storage:

1. Add the UUID to the `storage_disks` list in your `terraform.tfvars`
2. Run `terraform apply` to update your configuration

### Updating Services

To update containers to the latest version:

1. Either use Docker CLI from the host system to update individual containers
2. Or run `terraform apply` to update all configurations

### Backups

Container configurations are stored in Docker volumes. To back them up:

1. Use Docker CLI from the host system to export volumes

## Troubleshooting

- **Service not responding**: Check container status using `docker ps`
- **Network connectivity issues**: Verify Traefik is running and check network configurations
- **Storage issues**: Check disk mounts with `mount` command and verify MergerFS service is running

## License

This project is licensed under the MIT License - see the LICENSE file for details.