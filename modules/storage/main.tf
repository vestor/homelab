terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
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
  security_opts = ["apparmor:unconfined"]
  capabilities {
    add = ["SYS_ADMIN"]
  }

  depends_on = [null_resource.setup_disk_mounts]
}

# Storage health check - optional resource to monitor disk health
resource "null_resource" "setup_disk_health_monitoring" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Create a basic disk health check script that doesn't rely on smartmontools
      "sudo mkdir -p /etc/container-scripts",
      "sudo tee /etc/container-scripts/check_disk_health.sh > /dev/null << 'EOF'",
      "#!/bin/bash",
      "echo \"Disk Space Usage - $(date)\"",
      "echo \"=========================\"",
      "df -h | grep -v tmpfs",
      "echo \"\"",
      "echo \"Disk I/O Status\"",
      "echo \"==============\"",
      "iostat -x | grep -v loop",
      "EOF",
      "sudo chmod +x /etc/container-scripts/check_disk_health.sh",

      # Setup a systemd timer to run the check periodically
      "sudo tee /etc/systemd/system/disk-health-check.service > /dev/null << 'EOF'",
      "[Unit]",
      "Description=Simple Disk Health Check",
      "[Service]",
      "Type=oneshot",
      "ExecStart=/etc/container-scripts/check_disk_health.sh",
      "StandardOutput=journal+console",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",

      "sudo tee /etc/systemd/system/disk-health-check.timer > /dev/null << 'EOF'",
      "[Unit]",
      "Description=Run disk health check weekly",

      "[Timer]",
      "OnCalendar=weekly",
      "Persistent=true",

      "[Install]",
      "WantedBy=timers.target",
      "EOF",

      # Enable and start the timer
      "sudo systemctl daemon-reload || true",
      "sudo systemctl enable disk-health-check.timer || true",
      "sudo systemctl start disk-health-check.timer || true"
    ]
  }

  depends_on = [null_resource.setup_disk_mounts]
}