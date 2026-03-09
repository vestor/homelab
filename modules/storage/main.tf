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

      # Create local branch directory on boot disk (sda4) for mergerfs pool
      "sudo mkdir -p ${var.storage_mount_base}/local",

      # Clean stale fstab entries for storage disks before adding fresh ones
      "sudo sed -i '/\\/mnt\\/disks\\//d' /etc/fstab",

      # Generate fstab entries for UUID-based mounting
      # nofail: don't hang boot if disk is missing
      # nouuid: allow mount even if kernel has stale UUID from a USB disconnect/reconnect cycle
      "for uuid in ${join(" ", var.storage_disks)}; do",
      "  mount_path=${var.storage_mount_base}/$uuid",
      "  sudo mkdir -p $mount_path",
      "  echo \"UUID=$uuid $mount_path xfs defaults,nofail,nouuid 0 2\" | sudo tee -a /etc/fstab",
      "done",

      # Mount all disks from fstab
      "sudo mount -a || true",

      # Create required directories on each mounted disk
      "for uuid in ${join(" ", var.storage_disks)}; do",
      "  mount_path=${var.storage_mount_base}/$uuid",
      "  sudo mkdir -p $mount_path/{media,downloads}/{movies,tv,music}",
      "  sudo mkdir -p $mount_path/downloads/{complete,incomplete}",
      "  sudo chmod -R 755 $mount_path",
      "done",

      # Create directory structure on local branch
      "sudo mkdir -p ${var.storage_mount_base}/local/{media,downloads}/{movies,tv,music}",
      "sudo mkdir -p ${var.storage_mount_base}/local/downloads/{complete,incomplete}",
      "sudo chown -R 1000:1000 ${var.storage_mount_base}/local/media ${var.storage_mount_base}/local/downloads",
      "sudo chmod -R 775 ${var.storage_mount_base}/local/media ${var.storage_mount_base}/local/downloads",

      # Add SELinux context for container access
      "if [ $(getenforce) = 'Enforcing' ]; then",
      "  sudo chcon -R -t container_file_t ${var.storage_mount_base}/local",
      "  for uuid in ${join(" ", var.storage_disks)}; do",
      "    mount_path=${var.storage_mount_base}/$uuid",
      "    sudo chcon -R -t container_file_t $mount_path",
      "  done",
      "fi",
    ]
  }
}

# Use MergerFS in a container
# The hvalev/mergerfs entrypoint merges /disks/* into /merged.
# MERGERFS_PARAMS env var overrides /config/parameters.conf.
# rshared propagation on /merged ensures the FUSE mount is visible on the host.
resource "docker_container" "mergerfs" {
  name       = "mergerfs"
  image      = "hvalev/mergerfs:2.40.2.1"
  restart    = "unless-stopped"
  privileged = true

  env = [
    "MERGERFS_PARAMS=defaults,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=mfs,minfreespace=20G"
  ]

  # Source disks — entrypoint reads from /disks/*
  mounts {
    type   = "bind"
    target = "/disks"
    source = var.storage_mount_base
  }

  # FUSE mount target — entrypoint mounts at /merged
  # rshared propagation makes FUSE mount visible on the host at mergerfs_mount_path
  mounts {
    type   = "bind"
    target = "/merged"
    source = var.mergerfs_mount_path
    bind_options {
      propagation = "rshared"
    }
  }

  # FUSE device
  mounts {
    type   = "bind"
    target = "/dev/fuse"
    source = "/dev/fuse"
  }

  network_mode  = "host"
  security_opts = ["label=disable", "apparmor:unconfined"]
  capabilities {
    add = ["CAP_SYS_ADMIN"]
  }

  depends_on = [null_resource.setup_disk_mounts]
}

# Boot ordering: USB disks may bounce (disconnect/reconnect) during boot due
# to power draw on the USB-SATA bridge. This systemd oneshot retries mount -a
# every 10s for up to 2 minutes until storage disks are mounted, then restarts
# mergerfs and containers labeled "depends-on-storage=true" (see media module).
resource "null_resource" "late_mount_service" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      <<-SCRIPT
      sudo tee /etc/systemd/system/late-mount-mergerfs.service > /dev/null <<'EOF'
[Unit]
Description=Mount late USB disks and restart mergerfs + storage-dependent containers
After=multi-user.target docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c '\
  for i in $(seq 1 12); do \
    mount -a 2>/dev/null; \
    if findmnt ${var.storage_mount_base}/* -t xfs >/dev/null 2>&1; then break; fi; \
    sleep 10; \
  done; \
  docker restart mergerfs && sleep 3 && \
  docker ps -q --filter "label=depends-on-storage=true" | xargs -r docker restart'

[Install]
WantedBy=multi-user.target
EOF
      sudo systemctl daemon-reload
      sudo systemctl enable late-mount-mergerfs.service
      SCRIPT
    ]
  }

  depends_on = [docker_container.mergerfs]
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
