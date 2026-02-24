# Dashboard module outputs

output "dashboard_service_urls" {
  description = "URLs for all dashboard services"
  value = {
    whatsup = module.whatsup_docker.service_url
  }
}

output "container_names" {
  description = "Names of deployed dashboard containers"
  value = {
    whatsup = module.whatsup_docker.container_name
  }
}
