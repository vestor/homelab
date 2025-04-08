output "traefik_container_id" {
  description = "ID of the Traefik container"
  value       = docker_container.traefik.id
}

output "traefik_container_name" {
  description = "Name of the Traefik container"
  value       = docker_container.traefik.name
}

output "tailscale_container_id" {
  description = "ID of the Tailscale container"
  value       = docker_container.tailscale.id
}

output "coredns_container_id" {
  description = "ID of the CoreDNS container"
  value       = docker_container.coredns.id
}

# Output the Tailscale IP
output "tailscale_ip" {
  description = "Tailscale IP address"
  value       = data.external.tailscale_ip.result.ip
}

output "traefik_dashboard_url" {
  description = "URL for the Traefik dashboard"
  value       = "http://${var.ssh_host}:8081/dashboard/"
}