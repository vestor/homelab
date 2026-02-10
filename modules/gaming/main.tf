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
    "ENEMY_DROP_ITEM_RATE=3.0"
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