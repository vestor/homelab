variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "image" {
  description = "Docker image to use for the service"
  type        = string
}

variable "domain_name" {
  description = "Base domain name for Traefik routing"
  type        = string
}

variable "timezone" {
  description = "Timezone for the container"
  type        = string
  default     = "UTC"
}

variable "restart_policy" {
  description = "Container restart policy"
  type        = string
  default     = "unless-stopped"
}

variable "privileged" {
  description = "Run container in privileged mode"
  type        = bool
  default     = false
}

variable "container_user" {
  description = "User to run the container as (uid:gid format)"
  type        = string
  default     = ""  # Empty means use the container's default
}

variable "port_mappings" {
  description = "Map of port mappings (internal, external, protocol)"
  type = list(object({
    internal = number
    external = number
    protocol = optional(string, "tcp")
  }))
  default = []
}

variable "volume_mappings" {
  description = "Map of volume mappings"
  type = list(object({
    volume_name    = optional(string)
    host_path      = optional(string)
    container_path = string
    read_only      = optional(bool, false)
  }))
  default = []
}

variable "network_ids" {
  description = "List of network IDs to connect the container to"
  type        = list(string)
  default     = []
}

variable "enable_traefik" {
  description = "Whether to enable Traefik reverse proxy for this service"
  type        = bool
  default     = true
}

variable "web_port" {
  description = "Web UI port for Traefik loadbalancer"
  type        = number
  default     = 80
}

variable "custom_labels" {
  description = "Custom Docker labels to apply to the container"
  type        = map(string)
  default     = {}
}

variable "custom_env" {
  description = "Custom environment variables to pass to the container"
  type        = list(string)
  default     = []
}

variable "command" {
  description = "Custom command to run in the container"
  type        = list(string)
  default     = null
}

variable "healthcheck" {
  description = "Container healthcheck configuration"
  type = object({
    test         = list(string)
    interval     = optional(string, "30s")
    timeout      = optional(string, "10s")
    start_period = optional(string, "5s")
    retries      = optional(number, 3)
  })
  default = null
}

variable "capabilities" {
  description = "Container capabilities configuration"
  type = object({
    add  = optional(list(string), [])
    drop = optional(list(string), [])
  })
  default = null
}

variable "init" {
  description = "Run an init process inside the container"
  type        = bool
  default     = false
}

variable "must_run" {
  description = "If true, Terraform will ensure the container is running. Set to false for containers managed externally (e.g. toggle scripts)."
  type        = bool
  default     = true
}

variable "start" {
  description = "Whether to start the container on creation. Set to false for containers that should begin stopped."
  type        = bool
  default     = true
}

variable "restrict_to_admins" {
  description = "When true and Traefik is enabled, apply the admin-only IPAllowList middleware to block member IPs."
  type        = bool
  default     = true
}