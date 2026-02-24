terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.5"
    }
  }
}
# Storage module - Disk mounting and MergerFS

# Setup disk mounting with UUIDs
resource "null_resource" "setup_disk_mounts" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Create base directories
      "sudo mkdir -p ${var.storage_mount_base}",
      "sudo mkdir -p ${var.mergerfs_mount_path}",

      # Generate fstab entries for UUID-based mounting
      "for uuid in ${join(" ", var.storage_disks)}; do",
      "  disk_name=$uuid",
      "  mount_path=${var.storage_mount_base}/$disk_name",
      "  sudo mkdir -p $mount_path",
      "  if ! grep -q $uuid /etc/fstab; then",
      "    echo \"UUID=$uuid $mount_path xfs defaults 0 2\" | sudo tee -a /etc/fstab",
      "  fi",
      "done",

      # Mount all disks from fstab
      "sudo mount -a || true",

      # Create required directories on each mounted disk
      "for uuid in ${join(" ", var.storage_disks)}; do",
      "  disk_name=$uuid",
      "  mount_path=${var.storage_mount_base}/$disk_name",
      "  sudo mkdir -p $mount_path/{media,downloads}/{movies,tv,music}",
      "  sudo mkdir -p $mount_path/downloads/{complete,incomplete}",
      "  sudo chmod -R 755 $mount_path",
      "done",

      # Create directory structure in mergerfs mount path (will be mounted by container)
      "sudo mkdir -p ${var.mergerfs_mount_path}/{media,downloads}/{movies,tv,music}",
      "sudo mkdir -p ${var.mergerfs_mount_path}/downloads/{complete,incomplete}",

      "sudo chown -R 1000:1000 ${var.mergerfs_mount_path}/media ${var.mergerfs_mount_path}/downloads",
      "sudo chmod -R 775 ${var.mergerfs_mount_path}/media ${var.mergerfs_mount_path}/downloads",

      # Add SELinux context for container access
      "if [ $(getenforce) = 'Enforcing' ]; then",
      "  sudo chcon -R -t container_file_t ${var.mergerfs_mount_path}",
      "  for uuid in ${join(" ", var.storage_disks)}; do",
      "    disk_name=$uuid",
      "    mount_path=${var.storage_mount_base}/$disk_name",
      "    sudo chcon -R -t container_file_t $mount_path",
      "  done",
      "fi",
    ]
  }
}

# Use MergerFS in a container
resource "docker_container" "mergerfs" {
  name       = "mergerfs"
  image      = "hvalev/mergerfs:2.40.2.1"
  restart    = "unless-stopped"
  privileged = true

  # Command to run mergerfs
  command = [
    "-o",
    "defaults,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=mfs,umask=022,uid=1000,gid=1000,permissions",
    "/mnt/disks",
    "${var.mergerfs_mount_path}"
  ]

  # Mount the storage directory and mergerfs target
  volumes {
    host_path      = var.storage_mount_base
    container_path = "/mnt/disks"
  }
  volumes {
    host_path      = var.mergerfs_mount_path
    container_path = var.mergerfs_mount_path
  }

  # Ensure fuse is available
  volumes {
    host_path      = "/dev/fuse"
    container_path = "/dev/fuse"
  }

  # Add host networking to ensure proper access
  network_mode = "host"

  # Add security options for FUSE
  security_opts = ["label=disable", "apparmor:unconfined"]
  capabilities {
    add = ["CAP_SYS_ADMIN"]
  }

  depends_on = [null_resource.setup_disk_mounts]
}

# Scrutiny - SMART disk health monitoring
module "scrutiny" {
  source = "../service_template"

  service_name = "scrutiny"
  image        = "ghcr.io/analogj/scrutiny:master-omnibus"
  privileged   = true
  domain_name  = var.domain_name
  timezone     = var.timezone
  network_ids  = [var.traefik_network_id]

  web_port = 8080
  port_mappings = [
    { internal = 8080, external = 8085 }
  ]

  volume_mappings = [
    { volume_name = var.scrutiny_config_vol, container_path = "/opt/scrutiny/config" },
    { volume_name = var.scrutiny_influxdb_vol, container_path = "/opt/scrutiny/influxdb" },
    { host_path = "/run/udev", container_path = "/run/udev", read_only = true },
  ]

  custom_env = [
    "COLLECTOR_CRON_SCHEDULE=0 0 * * *"
  ]

  capabilities = { add = ["SYS_RAWIO"] }
}
