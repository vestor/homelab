# SSH Connection Variables
variable "ssh_host" {
  description = "CoreOS machine hostname or IP"
  type        = string
}

variable "ssh_user" {
  description = "SSH username for CoreOS machine"
  type        = string
  default     = "core"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# Domain and Network Variables
variable "domain_name" {
  description = "Base domain name for Traefik routing"
  type        = string
  default     = "homelab.local"
}

variable "timezone" {
  description = "Local timezone for containers"
  type        = string
  default     = "Asia/Kolkata"
}

# Storage Variables
variable "mergerfs_mount_path" {
  description = "Path where mergerfs will mount the combined storage"
  type        = string
  default     = "/mnt/mergerfs"
}

variable "storage_disks" {
  description = "List of disk UUIDs to include in mergerfs"
  type        = list(string)
  default     = []  # Empty default, should be set in terraform.tfvars
}

variable "storage_mount_base" {
  description = "Base path where individual disks will be mounted"
  type        = string
  default     = "/mnt/disks"
}

# Tailscale Variables
variable "tailscale_auth_key" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}

# Cloudflare Variables
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
