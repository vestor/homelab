output "glance_services" {
  description = "Service definitions for Glance dashboard"
  value = [
    {
      name         = "Grafana"
      group        = "Infrastructure"
      url          = "https://grafana.${var.domain_name}"
      icon         = "si:grafana"
      internal_url = "http://grafana:3000"
      github_repo  = "grafana/grafana"
    },
    {
      name         = "Prometheus"
      group        = "Infrastructure"
      url          = "https://prometheus.${var.domain_name}"
      icon         = "si:prometheus"
      internal_url = "http://prometheus:9090"
      github_repo  = "prometheus/prometheus"
    },
  ]
}
