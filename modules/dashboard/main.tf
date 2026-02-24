# Dashboards module - Glance, What's Up Docker

locals {
  # Infrastructure services defined locally (dashboard/networking concerns)
  infra_services = [
    {
      name         = "Traefik"
      group        = "Infrastructure"
      url          = "https://traefik.${var.domain_name}"
      icon         = "si:traefikproxy"
      internal_url = "http://${var.local_ip}:8080"
      github_repo  = "traefik/traefik"
    },
    {
      name         = "What's Up Docker"
      group        = "Infrastructure"
      url          = "https://whatsup.${var.domain_name}"
      icon         = ""
      internal_url = ""
      github_repo  = ""
    },
    {
      name         = "Glance"
      group        = "Infrastructure"
      url          = "https://${var.domain_name}"
      icon         = ""
      internal_url = ""
      github_repo  = "glanceapp/glance"
    },
  ]

  all_services = concat(var.glance_services, local.infra_services)

  # Group colors
  group_colors = {
    "Media"           = "40 60 55"
    "Media Management" = "270 40 60"
    "Home Automation"  = "200 50 60"
    "Infrastructure"   = "150 45 55"
    "Gaming"           = "0 55 60"
  }

  # Group services by category for bookmarks
  bookmark_groups = [
    for group_name, color in local.group_colors : {
      title = group_name
      color = color
      links = [
        for svc in local.all_services : {
          title = svc.name
          url   = svc.url
        }
        if svc.group == group_name
      ]
    }
    if length([for svc in local.all_services : svc if svc.group == group_name]) > 0
  ]

  # Services with internal URLs for health monitoring
  monitor_services = [
    for svc in local.all_services : {
      title = svc.name
      url   = svc.internal_url
      icon  = svc.icon
    }
    if svc.internal_url != ""
  ]

  # Services with GitHub repos for release tracking
  release_repos = [
    for svc in local.all_services : svc.github_repo
    if svc.github_repo != ""
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
      external = 3001
    }
  ]

  custom_env = [
    "WUD_WATCHER_DOCKER_HOST=${var.socket_proxy_name}",
    "WUD_WATCHER_DOCKER_PORT=2375",
    "WUD_WATCHER_DOCKER_SOCKET=tcp://${var.socket_proxy_name}",
    "WUD_UI_HOST=0.0.0.0",
    "WUD_UI_PORT=3000"
  ]

  volume_mappings = [
    {
      volume_name    = var.whatsup_docker_data_vol
      container_path = "/store"
    }
  ]
}

# Copy config file for Glance to the remote server
resource "null_resource" "glance_config_files" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  triggers = {
    glance_sha1 = sha1(templatefile("${path.root}/templates/glance.yaml.tftpl", {
      domain_name         = var.domain_name
      bookmark_groups     = local.bookmark_groups
      monitor_services    = local.monitor_services
      release_repos       = local.release_repos
      scrutiny_url        = var.scrutiny_url
      speedtest_url       = var.speedtest_url
      speedtest_api_token = var.speedtest_api_token
      uptime_kuma_url     = var.uptime_kuma_url
      local_ip            = var.local_ip
    }))
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/glance-config"
    ]
  }

  provisioner "file" {
    content     = templatefile("${path.root}/templates/glance.yaml.tftpl", {
      domain_name         = var.domain_name
      bookmark_groups     = local.bookmark_groups
      monitor_services    = local.monitor_services
      release_repos       = local.release_repos
      scrutiny_url        = var.scrutiny_url
      speedtest_url       = var.speedtest_url
      speedtest_api_token = var.speedtest_api_token
      uptime_kuma_url     = var.uptime_kuma_url
      local_ip            = var.local_ip
    })
    destination = "/tmp/glance-config/glance.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/${var.glance_config_vol}/_data",
      "sudo cp /tmp/glance-config/glance.yml /var/lib/docker/volumes/${var.glance_config_vol}/_data/glance.yml",
      "sudo chown -R 1000:1000 /var/lib/docker/volumes/${var.glance_config_vol}/_data/",
      "sudo chmod -R 755 /var/lib/docker/volumes/${var.glance_config_vol}/_data/",
      "rm -rf /tmp/glance-config"
    ]
  }
}

# Glance dashboard
module "glance" {
  source = "../service_template"
  depends_on = [null_resource.glance_config_files]

  service_name   = "glance"
  image          = "glanceapp/glance:latest"
  domain_name    = var.domain_name
  timezone       = var.timezone
  network_ids    = [var.traefik_network_id]
  container_user = "0:0"
  privileged     = true

  web_port     = 8080
  port_mappings = [
    {
      internal = 8080
      external = 8082
    }
  ]

  custom_labels = {
    "traefik.http.routers.glance.rule" = "Host(`glance.${var.domain_name}`) || Host(`${var.domain_name}`)"
  }

  volume_mappings = [
    {
      volume_name    = var.glance_config_vol
      container_path = "/app/config"
    },
    {
      host_path      = "/var/run/docker.sock"
      container_path = "/var/run/docker.sock"
      read_only      = true
    },
    {
      host_path      = "/"
      container_path = "/host"
      read_only      = true
    },
    {
      host_path      = var.mergerfs_mount_path
      container_path = var.mergerfs_mount_path
      read_only      = true
    }
  ]
}
