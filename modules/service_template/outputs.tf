output "container_id" {
  description = "ID of the created container"
  value       = docker_container.service.id
}

output "container_name" {
  description = "Name of the created container"
  value       = docker_container.service.name
}

output "container_ip" {
  description = "IP address of the container"
  value       = docker_container.service.network_data[0].ip_address
}

output "service_url" {
  description = "URL for accessing the service through Traefik"
  value       = var.enable_traefik ? "https://${var.service_name}.${var.domain_name}" : null
}