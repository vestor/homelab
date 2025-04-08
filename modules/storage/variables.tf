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

# Storage Variables
variable "mergerfs_mount_path" {
  description = "Path where mergerfs will mount the combined storage"
  type        = string
  default     = "/mnt/mergerfs"
}

variable "storage_disks" {
  description = "List of disk UUIDs to include in mergerfs"
  type        = list(string)
  default     = []

  # Validate that UUIDs are provided if the list is not empty
  validation {
    condition     = length(var.storage_disks) == 0 || alltrue([for disk in var.storage_disks : can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", disk))])
    error_message = "Storage disks must be specified as valid UUIDs (e.g., 12345678-1234-1234-1234-123456789abc)"
  }
}

variable "storage_mount_base" {
  description = "Base path where individual disks will be mounted"
  type        = string
  default     = "/mnt/disks"
}