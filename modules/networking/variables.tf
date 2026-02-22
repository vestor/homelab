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

# Network Configuration
variable "domain_name" {
  description = "Base domain name for Traefik routing"
  type        = string
}

variable "timezone" {
  description = "Local timezone for containers"
  type        = string
  default     = "UTC"
}

# Resource References
variable "traefik_network_id" {
  description = "ID of the Traefik network"
  type        = string
}

variable "socket_proxy_name" {
  description = "Name of the Docker socket proxy container"
  type        = string
}

# Volumes
variable "traefik_config_vol" {
  description = "Docker volume for Traefik configuration"
  type        = string
}

variable "traefik_acme_vol" {
  description = "Docker volume for Traefik ACME data"
  type        = string
}

variable "tailscale_data_vol" {
  description = "Docker volume for Tailscale data"
  type        = string
}

# Authentication
variable "tailscale_auth_key" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}

# Cloudflare
variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS verification"
  type        = string
  sensitive   = true
}

variable "cloudflare_email" {
  description = "Cloudflare account email"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain"
  type        = string
  sensitive   = true
}

variable "local_ip" {
  description = "Local LAN IP address of the CoreOS machine"
  type        = string
}