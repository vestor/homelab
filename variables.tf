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

variable "public_ip" {
  description = "Public IP address of the CoreOS machine"
  type        = string
}

variable "local_ip" {
  description = "Local LAN IP address of the CoreOS machine"
  type        = string
}

# Palworld Server Variables
variable "palworld_server_password" {
  description = "Palworld server password"
  type        = string
  sensitive   = true
}

variable "palworld_admin_password" {
  description = "Palworld admin password for RCON"
  type        = string
  sensitive   = true
}

variable "palworld_player_count" {
  description = "Maximum number of players allowed on the Palworld server"
  type        = number
  default     = 10
}

variable "palworld_server_name" {
  description = "Name of the Palworld server"
  type        = string
  default     = "Cyberstaan"
}

variable "palworld_server_description" {
  description = "Description of the Palworld server"
  type        = string
  default     = "Welcome to Cyberstaan"
}

variable "paledit_password" {
  description = "Password for Palworld Pal Editor web UI"
  type        = string
  sensitive   = true
}
