# Home Automation module - Home Assistant, HyperHDR

# Home Assistant
module "homeassistant" {
  source = "../service_template"

  service_name  = "homeassistant"
  image         = "homeassistant/home-assistant:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = [var.traefik_network_id]

  web_port     = 8123
  port_mappings = [
    {
      internal = 8123
      external = 8123
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.homeassistant_config_vol
      container_path = "/config"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Home Automation"
    "homepage.name"        = "Home Assistant"
    "homepage.icon"        = "home-assistant.png"
    "homepage.href"        = "https://homeassistant.${var.domain_name}"
    "homepage.description" = "Home Automation Platform"
  }
}

# Set up HyperHDR container
resource "null_resource" "prepare_hyperhdr_context" {
  # Add triggers to force recreation if needed
  triggers = {
    # This will force recreation whenever you run 'terraform apply -replace=module.home_automation.null_resource.prepare_hyperhdr_context'
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
    # Add timeout to prevent hanging indefinitely
    agent       = false  # Don't use SSH agent
    timeout     = "30s"
  }

  # First make sure the directory exists with proper permissions
  provisioner "remote-exec" {
    inline = [
      "echo 'Creating HyperHDR build directory...'",
      "sudo mkdir -p /opt/docker-builds/hyperhdr",
      "sudo chmod 777 /opt/docker-builds/hyperhdr",
      "echo 'Directory created and permissions set.'"
    ]
  }

  # Upload the Dockerfile from local templates folder to the remote server
  provisioner "file" {
    source      = "${path.root}/templates/hyperhdr.dockerfile"
    destination = "/opt/docker-builds/hyperhdr/Dockerfile"
  }
}

resource "null_resource" "build_hyperhdr_image" {
  depends_on = [null_resource.prepare_hyperhdr_context]

  # Add a trigger that changes whenever the Dockerfile changes
  triggers = {
    dockerfile_sha1 = sha1(file("${path.root}/templates/hyperhdr.dockerfile"))
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Remove any existing image first to force rebuild
      "sudo docker image rm -f custom-hyperhdr:latest || true",
      # Build the image using the uploaded Dockerfile
      "cd /opt/docker-builds/hyperhdr && sudo docker build -t custom-hyperhdr:latest .",
      # Verify the image was created
      "sudo docker images | grep custom-hyperhdr"
    ]
  }
}

# HyperHDR container
module "hyperhdr" {
  source = "../service_template"
  depends_on = [null_resource.build_hyperhdr_image]

  service_name  = "hyperhdr"
  image         = "custom-hyperhdr:latest"
  domain_name   = var.domain_name
  timezone      = var.timezone
  network_ids   = [var.traefik_network_id]
  privileged    = true

  web_port     = 8090
  port_mappings = [
    {
      internal = 19400
      external = 19400
    },
    {
      internal = 19444
      external = 19444
    },
    {
      internal = 19445
      external = 19445
    },
    {
      internal = 8090
      external = 8090
    },
    {
      internal = 8092
      external = 8092
    }
  ]

  volume_mappings = [
    {
      volume_name    = var.hyperhdr_config_vol
      container_path = "/config"
    }
  ]

  custom_labels = {
    "homepage.group"       = "Home Automation"
    "homepage.name"        = "HyperHDR"
    "homepage.icon"        = "hyperhdr.png"
    "homepage.href"        = "https://hyperhdr.${var.domain_name}"
    "homepage.description" = "Ambient Lighting Control"
  }
}