output "mergerfs_container_id" {
  description = "ID of the MergerFS container"
  value       = docker_container.mergerfs.id
}

output "mergerfs_container_name" {
  description = "Name of the MergerFS container"
  value       = docker_container.mergerfs.name
}

output "mounted_disks" {
  description = "List of mounted disk UUIDs"
  value       = var.storage_disks
}

output "storage_path" {
  description = "Path to the merged storage"
  value       = var.mergerfs_mount_path
}

output "glance_services" {
  description = "Services to display in Glance dashboard"
  value = [{
    name         = "Scrutiny"
    group        = "Infrastructure"
    url          = "https://scrutiny.${var.domain_name}"
    icon         = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/scrutiny.svg"
    internal_url = "http://scrutiny:8080"
    github_repo  = "AnalogJ/scrutiny"
  }]
}