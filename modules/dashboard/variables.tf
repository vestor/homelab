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

# Glance services from other modules
variable "glance_services" {
  description = "List of services to display in Glance dashboard"
  type = list(object({
    name         = string
    group        = string
    url          = string
    icon         = optional(string, "")
    internal_url = optional(string, "")
    github_repo  = optional(string, "")
  }))
  default = []
}

# Volume Variables
variable "whatsup_docker_data_vol" {
  description = "Docker volume for What's Up Docker data"
  type        = string
}

variable "glance_config_vol" {
  description = "Docker volume for Glance configuration"
  type        = string
}

variable "scrutiny_url" {
  description = "Internal URL for Scrutiny API"
  type        = string
  default     = "http://scrutiny:8080"
}

variable "speedtest_url" {
  description = "Internal URL for Speedtest Tracker API"
  type        = string
  default     = "http://speedtest:80"
}

variable "speedtest_api_token" {
  description = "Speedtest Tracker API token for Glance widget"
  type        = string
  sensitive   = true
  default     = ""
}

variable "uptime_kuma_url" {
  description = "External URL for Uptime Kuma"
  type        = string
  default     = ""
}

variable "local_ip" {
  description = "Local LAN IP address of the CoreOS machine"
  type        = string
  default     = ""
}
