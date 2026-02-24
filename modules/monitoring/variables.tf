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

variable "domain_name" {
  description = "Base domain name for Traefik routing"
  type        = string
}

variable "timezone" {
  description = "Local timezone for containers"
  type        = string
}

variable "local_ip" {
  description = "Local LAN IP address of the CoreOS machine"
  type        = string
}

variable "traefik_network_id" {
  description = "ID of the Traefik network"
  type        = string
}

variable "prometheus_config_vol" {
  description = "Docker volume for Prometheus configuration"
  type        = string
}

variable "prometheus_data_vol" {
  description = "Docker volume for Prometheus time-series data"
  type        = string
}

variable "grafana_data_vol" {
  description = "Docker volume for Grafana data"
  type        = string
}
