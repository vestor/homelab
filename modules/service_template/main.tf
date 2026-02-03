terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.5"
    }
  }
}
# Generic service template module
# This can be used as a basis for new services with common configurations

locals {
  # Default labels for Traefik if enabled
  traefik_labels = var.enable_traefik ? {
    "traefik.enable"                                              = "true"
    "traefik.http.routers.${var.service_name}.rule"              = "Host(`${var.service_name}.${var.domain_name}`)"
    "traefik.http.routers.${var.service_name}.entrypoints"       = "web,websecure"
    "traefik.http.routers.${var.service_name}.tls"               = "true"
    "traefik.http.routers.${var.service_name}.tls.certresolver"  = "cloudflare"
    "traefik.http.services.${var.service_name}.loadbalancer.server.port" = tostring(var.web_port)
  } : {}

  # Merge default and custom labels
  merged_labels = { for k, v in merge(local.traefik_labels, var.custom_labels) : k => v }

  # Default environment variables
  default_env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=${var.timezone}"
  ]

  # Merge default and custom environment variables
  merged_env = concat(local.default_env, var.custom_env)

  # Extract network references from IDs
  networks = [for net_id in var.network_ids : {
    name = net_id
  }]
}

# The service container
resource "docker_container" "service" {
  name       = var.service_name
  image      = var.image
  restart    = var.restart_policy
  privileged = var.privileged
  user       = var.container_user

  # Dynamic ports based on provided map
  dynamic "ports" {
    for_each = var.port_mappings
    content {
      internal = ports.value.internal
      external = ports.value.external
      protocol = lookup(ports.value, "protocol", "tcp")
    }
  }

  # Environment variables
  env = local.merged_env

  # Dynamic volumes based on provided map
  dynamic "volumes" {
    for_each = var.volume_mappings
    content {
      volume_name    = lookup(volumes.value, "volume_name", null)
      host_path      = lookup(volumes.value, "host_path", null)
      container_path = volumes.value.container_path
      read_only      = lookup(volumes.value, "read_only", false)
    }
  }

  # Dynamic networks based on provided IDs
  dynamic "networks_advanced" {
    for_each = local.networks
    content {
      name = networks_advanced.value.name
    }
  }

  # Dynamic labels based on merged default and custom
  dynamic "labels" {
    for_each = local.merged_labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  # Add custom commands if provided
  command = var.command

  # Add healthcheck if provided
  dynamic "healthcheck" {
    for_each = var.healthcheck != null ? [var.healthcheck] : []
    content {
      test         = healthcheck.value.test
      interval     = lookup(healthcheck.value, "interval", "30s")
      timeout      = lookup(healthcheck.value, "timeout", "10s")
      start_period = lookup(healthcheck.value, "start_period", "5s")
      retries      = lookup(healthcheck.value, "retries", 3)
    }
  }

  # Add capabilities if provided
  dynamic "capabilities" {
    for_each = var.capabilities != null ? [var.capabilities] : []
    content {
      add  = lookup(capabilities.value, "add", [])
      drop = lookup(capabilities.value, "drop", [])
    }
  }
}