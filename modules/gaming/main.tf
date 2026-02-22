locals {
  networks = [var.traefik_network_id]
}

# Palworld dedicated server
module "palworld" {
  source = "../service_template"

  service_name  = "palworld"
  image         = "thijsvanloef/palworld-server-docker:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks
  enable_traefik = false  # Game servers typically don't use HTTP
  must_run      = false   # Managed by toggle service

  port_mappings = [
    {
      internal = 8211
      external = 8211
      protocol = "udp"
    },
    {
      internal = 8211
      external = 8211
      protocol = "tcp"
    },
    {
      internal = 27015
      external = 27015
      protocol = "udp"
    }
  ]

  custom_env = [
    "PORT=8211",
    "PLAYERS=${var.palworld_player_count}",
    "MULTITHREADING=true",
    "COMMUNITY=true",
    "PUBLIC_IP=${var.public_ip}",
    "PUBLIC_PORT=8211",
    "SERVER_NAME=${var.palworld_server_name}",
    "SERVER_DESCRIPTION=${var.palworld_server_description}",
    "SERVER_PASSWORD=${var.palworld_server_password}",
    "ADMIN_PASSWORD=${var.palworld_admin_password}",
    "UPDATE_ON_BOOT=true",
    "RCON_ENABLED=true",
    "RCON_PORT=27015",
    "QUERY_PORT=27016",
    "BACKUP_ENABLED=true",
    "BACKUP_CRON_EXPRESSION=0 0 * * *",
    "DELETE_OLD_BACKUPS=true",
    "OLD_BACKUP_DAYS=30",
    "CROSSPLAY_PLATFORMS=(Steam,Xbox,PS5,Mac)",
    "ITEM_WEIGHT_RATE=0.0",
    "DEATH_PENALTY=None",
    "PAL_STAMINA_DECREASE_RATE=0.1",
    "PAL_CAPTURE_RATE=1.5",
    "PAL_EGG_DEFAULT_HATCHING_TIME=0",
    "BASE_CAMP_MAX_NUM=6",
    "BASE_CAMP_WORKER_MAX_NUM=25",
    "BUILD_OBJECT_DETERIORATION_DAMAGE_RATE=0",
    "EQUIPMENT_DURABILITY_DAMAGE_RATE=0.1",
    "SUPPLY_DROP_SPAN=10",
    "BASE_CAMP_MAX_NUM_IN_GUILD=6",
    "PAL_SPAWN_NUM_RATE=3.0",
    "COLLECTION_DROP_RATE=3.0",
    "ENEMY_DROP_ITEM_RATE=3.0",
    "ENABLE_INVADER_ENEMY=false"
  ]

  volume_mappings = [
    {
      volume_name    = var.palworld_config_vol
      container_path = "/palworld"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Gaming"
    "homepage.name"        = "Palworld"
    "homepage.icon"        = "palworld.png"
    "homepage.description" = "Palworld Dedicated Server"
  }
}

# Upload toggle script to Docker volume via SSH
resource "null_resource" "toggle_script" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  triggers = {
    script_sha1 = sha1(file("${path.root}/templates/palworld-toggle.py.tftpl"))
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/toggle-config"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/templates/palworld-toggle.py.tftpl"
    destination = "/tmp/toggle-config/toggle.py"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/${var.palworld_toggle_data_vol}/_data",
      "sudo cp /tmp/toggle-config/toggle.py /var/lib/docker/volumes/${var.palworld_toggle_data_vol}/_data/toggle.py",
      "sudo chmod 755 /var/lib/docker/volumes/${var.palworld_toggle_data_vol}/_data/toggle.py",
      "rm -rf /tmp/toggle-config"
    ]
  }
}

# Palworld Pal Editor - web-based save editor
module "paledit" {
  source = "../service_template"

  service_name  = "paledit"
  image         = "ghcr.io/kriscris/palworld-pal-editor:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = local.networks
  must_run      = false  # Managed by toggle service
  start         = false  # Starts stopped; toggle service starts it
  restrict_to_admins = false

  web_port     = 58888
  port_mappings = [
    {
      internal = 58888
      external = 8083
    }
  ]

  custom_env = [
    "MODE=web",
    "PASSWORD=${var.paledit_password}",
    "APP_PORT=58888",
    "APP_LANG=en"
  ]

  volume_mappings = [
    {
      host_path      = "/var/lib/docker/volumes/${var.palworld_config_vol}/_data/Pal/Saved/SaveGames/0/${var.palworld_world_id}"
      container_path = "/mnt/gamesave"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Gaming"
    "homepage.name"        = "Pal Editor"
    "homepage.icon"        = "palworld.png"
    "homepage.description" = "Palworld Save Editor"
  }
}

# Toggle service - controls palworld/paledit switching
module "palworld_toggle" {
  source     = "../service_template"
  depends_on = [null_resource.toggle_script]

  service_name   = "palworld-toggle"
  image          = "python:3-alpine"
  domain_name    = var.domain_name
  timezone       = var.timezone
  network_ids    = local.networks
  privileged     = true
  container_user = "0:0"
  command        = ["python", "/app/toggle.py"]
  restrict_to_admins = false

  web_port     = 8090
  port_mappings = [
    {
      internal = 8090
      external = 8084
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.palworld_toggle_data_vol
      container_path = "/app"
      read_only      = true
    },
    {
      host_path      = "/var/run/docker.sock"
      container_path = "/var/run/docker.sock"
    }
  ]

  custom_labels = {
    "traefik.http.routers.palworld-toggle.rule" = "Host(`toggle.${var.domain_name}`)"
  }
}