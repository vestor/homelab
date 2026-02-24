terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.5"
    }
  }
}

# Monitoring module - node_exporter, Prometheus, Grafana

# node_exporter - host metrics collector (requires host networking)
resource "docker_container" "node_exporter" {
  name         = "node-exporter"
  image        = "prom/node-exporter:latest"
  restart      = "unless-stopped"
  network_mode = "host"
  pid_mode     = "host"

  command = [
    "--path.procfs=/host/proc",
    "--path.sysfs=/host/sys",
    "--path.rootfs=/host/root",
    "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)",
  ]

  volumes {
    host_path      = "/proc"
    container_path = "/host/proc"
    read_only      = true
  }

  volumes {
    host_path      = "/sys"
    container_path = "/host/sys"
    read_only      = true
  }

  volumes {
    host_path      = "/"
    container_path = "/host/root"
    read_only      = true
  }
}

# Provision Prometheus configuration via SSH
resource "null_resource" "prometheus_config" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  triggers = {
    config_sha1 = sha1(templatefile("${path.root}/templates/prometheus.yml.tftpl", {
      local_ip = var.local_ip
    }))
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/prometheus-config"
    ]
  }

  provisioner "file" {
    content = templatefile("${path.root}/templates/prometheus.yml.tftpl", {
      local_ip = var.local_ip
    })
    destination = "/tmp/prometheus-config/prometheus.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/${var.prometheus_config_vol}/_data",
      "sudo cp /tmp/prometheus-config/prometheus.yml /var/lib/docker/volumes/${var.prometheus_config_vol}/_data/prometheus.yml",
      "sudo chmod 644 /var/lib/docker/volumes/${var.prometheus_config_vol}/_data/prometheus.yml",
      "rm -rf /tmp/prometheus-config"
    ]
  }
}

# Prometheus - time-series database
module "prometheus" {
  source     = "../service_template"
  depends_on = [null_resource.prometheus_config]

  service_name   = "prometheus"
  image          = "quay.io/prometheus/prometheus:latest"
  domain_name    = var.domain_name
  timezone       = var.timezone
  network_ids    = [var.traefik_network_id]
  container_user = "0:0"

  web_port = 9090
  port_mappings = [
    { internal = 9090, external = 9191 }
  ]

  volume_mappings = [
    { volume_name = var.prometheus_config_vol, container_path = "/etc/prometheus" },
    { volume_name = var.prometheus_data_vol, container_path = "/prometheus" },
  ]
}

# Provision Grafana datasource and dashboard configuration via SSH
resource "null_resource" "grafana_provisioning" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  triggers = {
    dashboards_sha1 = sha1(join("", [
      file("${path.root}/templates/grafana/network-traffic.json"),
      file("${path.root}/templates/grafana/homelab-server.json"),
    ]))
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/${var.grafana_data_vol}/_data/provisioning/datasources",
      "sudo mkdir -p /var/lib/docker/volumes/${var.grafana_data_vol}/_data/provisioning/dashboards",
      "mkdir -p /tmp/grafana-provisioning"
    ]
  }

  # Datasource config
  provisioner "file" {
    content = yamlencode({
      apiVersion  = 1
      datasources = [{
        name      = "Prometheus"
        type      = "prometheus"
        access    = "proxy"
        url       = "http://prometheus:9090"
        isDefault = true
        editable  = false
      }]
    })
    destination = "/tmp/grafana-provisioning/datasource.yml"
  }

  # Dashboard provider config
  provisioner "file" {
    content = yamlencode({
      apiVersion = 1
      providers  = [{
        name                = "default"
        orgId               = 1
        folder              = ""
        type                = "file"
        disableDeletion     = false
        updateIntervalSeconds = 30
        options = {
          path                      = "/var/lib/grafana/provisioning/dashboards"
          foldersFromFilesStructure = false
        }
      }]
    })
    destination = "/tmp/grafana-provisioning/dashboards.yml"
  }

  # Dashboard JSON files
  provisioner "file" {
    source      = "${path.root}/templates/grafana/network-traffic.json"
    destination = "/tmp/grafana-provisioning/network-traffic.json"
  }

  provisioner "file" {
    source      = "${path.root}/templates/grafana/homelab-server.json"
    destination = "/tmp/grafana-provisioning/homelab-server.json"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /tmp/grafana-provisioning/datasource.yml /var/lib/docker/volumes/${var.grafana_data_vol}/_data/provisioning/datasources/datasource.yml",
      "sudo cp /tmp/grafana-provisioning/dashboards.yml /var/lib/docker/volumes/${var.grafana_data_vol}/_data/provisioning/dashboards/dashboards.yml",
      "sudo cp /tmp/grafana-provisioning/network-traffic.json /var/lib/docker/volumes/${var.grafana_data_vol}/_data/provisioning/dashboards/network-traffic.json",
      "sudo cp /tmp/grafana-provisioning/homelab-server.json /var/lib/docker/volumes/${var.grafana_data_vol}/_data/provisioning/dashboards/homelab-server.json",
      "sudo chown -R 472:472 /var/lib/docker/volumes/${var.grafana_data_vol}/_data",
      "rm -rf /tmp/grafana-provisioning"
    ]
  }
}

# Grafana - visualization dashboards
module "grafana" {
  source     = "../service_template"
  depends_on = [null_resource.grafana_provisioning]

  service_name = "grafana"
  image        = "grafana/grafana:latest"
  domain_name  = var.domain_name
  timezone     = var.timezone
  network_ids  = [var.traefik_network_id]

  web_port = 3000
  port_mappings = [
    { internal = 3000, external = 3100 }
  ]

  volume_mappings = [
    { volume_name = var.grafana_data_vol, container_path = "/var/lib/grafana" },
  ]

  custom_env = [
    "GF_PATHS_PROVISIONING=/var/lib/grafana/provisioning",
    "GF_SECURITY_ALLOW_EMBEDDING=true",
    "GF_AUTH_ANONYMOUS_ENABLED=true",
    "GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer",
    "GF_SERVER_ROOT_URL=https://grafana.${var.domain_name}",
  ]
}
