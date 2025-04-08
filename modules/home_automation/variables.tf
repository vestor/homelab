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

# Network Variables
variable "traefik_network_id" {
  description = "ID of the Traefik network"
  type        = string
}

# Volume Variables
variable "homeassistant_config_vol" {
  description = "Docker volume for Home Assistant configuration"
  type        = string
}

variable "hyperhdr_config_vol" {
  description = "Docker volume for HyperHDR configuration"
  type        = string
}