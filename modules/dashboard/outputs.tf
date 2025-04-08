# Dashboard module outputs

output "dashboard_service_urls" {
  description = "URLs for all dashboard services"
  value = {
    homepage = module.homepage.service_url
    whatsup  = module.whatsup_docker.service_url
  }
}

output "container_names" {
  description = "Names of deployed dashboard containers"
  value = {
    homepage   = module.homepage.container_name
    watchtower = module.watchtower.container_name
    whatsup    = module.whatsup_docker.container_name
  }
}