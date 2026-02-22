# Network Configuration
variable "traefik_network_id" {
  description = "ID of the Traefik network"
  type        = string
}

# Volumes
variable "palworld_config_vol" {
  description = "Docker volume for Palworld configuration"
  type        = string
}
variable "palworld_server_password" {
  description = "Palworld Server Password"
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

variable "palworld_admin_password" {
  description = "Palworld Admin Password"
  type        = string
  sensitive   = true
}

variable "public_ip" {
  description = "Public IP address for the Palworld server"
  type        = string
}

variable "domain_name" {
  description = "Base domain name for Traefik routing"
  type        = string
}

variable "timezone" {
  description = "Local timezone for containers"
  type        = string
  default     = "UTC"
}

# SSH Connection Variables (for provisioners)
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

# Pal Editor Variables
variable "palworld_toggle_data_vol" {
  description = "Docker volume for Palworld toggle service data"
  type        = string
}

variable "palworld_world_id" {
  description = "Palworld world save ID (folder name under SaveGames/0/)"
  type        = string
  default     = "7037312B4AE09E7F3D022CAD013BACFA"
}

variable "paledit_password" {
  description = "Password for Palworld Pal Editor web UI"
  type        = string
  sensitive   = true
}
