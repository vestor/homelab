# Connection Variables
variable "ssh_host" {
  description = "CoreOS machine hostname or IP"
  type        = string
}

variable "ssh_user" {
  description = "SSH username for CoreOS machine"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
}

# Service Variables
variable "domain_name" {
  description = "Base domain name for Traefik routing"
  type        = string
}

variable "timezone" {
  description = "Local timezone for containers"
  type        = string
  default     = "UTC"
}

variable "mergerfs_mount_path" {
  description = "Path where mergerfs will mount the combined storage"
  type        = string
}

# Network Variables
variable "traefik_network_id" {
  description = "ID of the Traefik network"
  type        = string
}

variable "socket_proxy_name" {
  description = "Name of the Docker socket proxy container"
  type        = string
}

# Volume Variables
variable "homepage_config_vol" {
  description = "Docker volume for Homepage configuration"
  type        = string
}

variable "whatsup_docker_data_vol" {
  description = "Docker volume for What's Up Docker data"
  type        = string
}

variable "glance_config_vol" {
  description = "Docker volume for Glance configuration"
  type        = string
}