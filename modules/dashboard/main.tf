# Dashboards module - Homepage, WhatSup Docker, Watchtower

# Copy config files for Homepage to the remote server
resource "null_resource" "homepage_config_files" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  # Use a trigger to update configs when the template content changes
  triggers = {
    services_sha1 = sha1(templatefile("${path.root}/templates/services.yaml.tftpl", {
      domain_name = var.domain_name
      ssh_host = var.ssh_host
    }))
    settings_sha1 = sha1(templatefile("${path.root}/templates/settings.yaml.tftpl", {}))
    widgets_sha1 = sha1(templatefile("${path.root}/templates/widgets.yaml.tftpl", {
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
    content     = templatefile("${path.root}/templates/services.yaml.tftpl", {
      domain_name = var.domain_name
      ssh_host = var.ssh_host
    })
    destination = "/tmp/homepage-config/services.yaml"
  }

  provisioner "file" {
    content     = templatefile("${path.root}/templates/settings.yaml.tftpl", {})
    destination = "/tmp/homepage-config/settings.yaml"
  }

  provisioner "file" {
    content     = templatefile("${path.root}/templates/widgets.yaml.tftpl", {
      mergerfs_mount_path = var.mergerfs_mount_path
    })
    destination = "/tmp/homepage-config/widgets.yaml"
  }

  # Copy files to the Docker volume
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/${var.homepage_config_vol}/_data",
      "sudo cp /tmp/homepage-config/*.yaml /var/lib/docker/volumes/${var.homepage_config_vol}/_data/",
      "sudo chown -R 1000:1000 /var/lib/docker/volumes/${var.homepage_config_vol}/_data/",
      "sudo chmod -R 755 /var/lib/docker/volumes/${var.homepage_config_vol}/_data/",
      "rm -rf /tmp/homepage-config"
    ]
  }
}

# Homepage dashboard
module "homepage" {
  source = "../service_template"
  depends_on = [null_resource.homepage_config_files]

  service_name  = "homepage"
  image         = "ghcr.io/gethomepage/homepage:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = [var.traefik_network_id]

  web_port     = 3000
  port_mappings = [
    {
      internal = 3000
      external = 3000
    }
  ]

  custom_env = [
    "HOMEPAGE_VAR_DOCKER_HOST=${var.socket_proxy_name}",
    "HOMEPAGE_VAR_DOCKER_PORT=2375",
    "HOMEPAGE_VAR_DOCKER_SOCKET=tcp",
    "HOMEPAGE_ALLOWED_HOSTS=homelab:3000,localhost:3000,127.0.0.1:3000"
  ]

  volume_mappings = [
    {
      volume_name    = var.homepage_config_vol
      container_path = "/app/config"
    }
  ]
}

# Watchtower - automatic container updates
module "watchtower" {
  source = "../service_template"

  service_name  = "watchtower"
  image         = "containrrr/watchtower:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = [var.traefik_network_id]
  enable_traefik = false

  custom_env = [
    "WATCHTOWER_CLEANUP=true",                 # Remove old images
    "WATCHTOWER_INCLUDE_STOPPED=false",        # Only update running containers
    "WATCHTOWER_NOTIFICATION_REPORT=true",     # More detailed notifications
    "WATCHTOWER_POLL_INTERVAL=86400",          # Check for updates once a day (in seconds)
    "WATCHTOWER_TIMEOUT=60s",                  # Timeout for container operations
    "WATCHTOWER_ROLLING_RESTART=true",         # Restart containers one by one
    "DOCKER_HOST=tcp://${var.socket_proxy_name}:2375"  # Connect to Docker via the socket proxy
  ]

  volume_mappings = [
    {
      volume_name    = var.watchtower_config_vol
      container_path = "/config"
    }
  ]
}

# What's Up Docker - container update monitoring
module "whatsup_docker" {
  source = "../service_template"

  service_name  = "whatsup"
  image         = "fmartinou/whats-up-docker:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = [var.traefik_network_id]

  web_port     = 3000
  port_mappings = [
    {
      internal = 3000
      external = 3001  # Using 3001 to avoid conflict with homepage
    }
  ]

  custom_env = [
    "WUD_WATCHER_DOCKER_HOST=${var.socket_proxy_name}",
    "WUD_WATCHER_DOCKER_PORT=2375",
    "WUD_WATCHER_DOCKER_SOCKET=tcp://${var.socket_proxy_name}",
    "WUD_UI_HOST=0.0.0.0",
    "WUD_UI_PORT=3000",
    "WUD_TRIGGER_WATCHTOWER=true",
    "WUD_TRIGGER_WATCHTOWER_ARGS=--cleanup"
  ]

  volume_mappings = [
    {
      volume_name    = var.whatsup_docker_data_vol
      container_path = "/store"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Management"
    "homepage.name"        = "What's Up Docker"
    "homepage.icon"        = "docker.png"
    "homepage.href"        = "https://whatsup.${var.domain_name}"
    "homepage.description" = "Docker Update Monitor"
  }

  depends_on = [module.watchtower]
}