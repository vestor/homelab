terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.5"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.35.0"
    }
  }
}
# Networking module - Traefik, Tailscale, CoreDNS, Cloudflare

# Update the Traefik configuration with Cloudflare and Let's Encrypt
resource "null_resource" "traefik_config" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/${var.traefik_config_vol}/_data",
      "sudo cat > /tmp/traefik.yml << 'EOL'",
      "entryPoints:",
      "  web:",
      "    address: ':80'",
      "    http:",
      "      redirections:",
      "        entryPoint:",
      "          to: websecure",
      "          scheme: https",
      "  websecure:",
      "    address: ':443'",
      "  tailscale:",
      "    address: ':8443'",
      "providers:",
      "  docker:",
      "    endpoint: 'tcp://${var.socket_proxy_name}:2375'",
      "    exposedByDefault: false",
      "    network: traefik_net",
      "    watch: true",
      "api:",
      "  dashboard: true",
      "  insecure: true",
      "certificatesResolvers:",
      "  cloudflare:",
      "    acme:",
      "      email: '${var.cloudflare_email}'",
      "      storage: /acme/acme.json",
      "      dnsChallenge:",
      "        provider: cloudflare",
      "        resolvers:",
      "          - '1.1.1.1:53'",
      "          - '1.0.0.1:53'",
      "log:",
      "  level: 'INFO'",
      "EOL",
      "sudo cp /tmp/traefik.yml /var/lib/docker/volumes/${var.traefik_config_vol}/_data/",

      # Create dynamic configuration for middleware
      "sudo mkdir -p /var/lib/docker/volumes/${var.traefik_config_vol}/_data/configs",
      "sudo cat > /tmp/dynamic.yml << 'EOL'",
      "http:",
      "  middlewares:",
      "    tailscale-ip-whitelist:",
      "      ipAllowList:",
      "        sourceRange:",
      "          - '127.0.0.1/32'       # Local traffic",
      "          - '192.168.0.0/16'     # Local LAN traffic",
      "          - '10.0.0.0/8'         # Tailscale IP range",
      "          - '100.64.0.0/10'      # Tailscale IP range (CGNAT)",
      "    local-ip-whitelist:",
      "      ipAllowList:",
      "        sourceRange:",
      "          - '127.0.0.1/32'       # Local traffic",
      "          - '192.168.0.0/16'     # Local LAN traffic",
      "EOL",
      "sudo cp /tmp/dynamic.yml /var/lib/docker/volumes/${var.traefik_config_vol}/_data/configs/",
      "sudo chmod 644 /var/lib/docker/volumes/${var.traefik_config_vol}/_data/traefik.yml",
      "sudo chmod 644 /var/lib/docker/volumes/${var.traefik_config_vol}/_data/configs/dynamic.yml",
      "rm /tmp/traefik.yml /tmp/dynamic.yml"
    ]
  }
}

# Update the Traefik container with HTTPS support and Cloudflare DNS
resource "docker_container" "traefik" {
  name  = "traefik"
  image = "traefik:v3.6"
  restart = "unless-stopped"
  user = "0:0"

  # Add a brief delay before Traefik starts to ensure socket-proxy is ready
  command = [
    "sh", "-c",
    "sleep 5 && /usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml"
  ]

  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 443
    external = 443
  }
  ports {
    internal = 8080
    external = 8081
  }
  ports {
    internal = 8443
    external = 8443
  }

  env = [
    "CF_API_EMAIL=${var.cloudflare_email}",
    "CF_DNS_API_TOKEN=${var.cloudflare_api_token}",
    "CF_ZONE_API_TOKEN=${var.cloudflare_api_token}",
    "TZ=${var.timezone}"
  ]

  volumes {
    volume_name    = var.traefik_config_vol
    container_path = "/etc/traefik"
  }
  volumes {
    volume_name    = var.traefik_acme_vol
    container_path = "/acme"
  }

  networks_advanced {
    name = var.traefik_network_id
  }

  depends_on = [
    null_resource.traefik_config
  ]
}

resource "docker_container" "tailscale" {
  name  = "tailscale"
  image = "tailscale/tailscale:latest"
  restart = "unless-stopped"
  network_mode = "host"
  privileged   = true

  env = [
    "TS_AUTH_KEY=${var.tailscale_auth_key}",
    "TS_STATE_DIR=/var/lib/tailscale",
    "TS_EXTRA_ARGS=--hostname=homelab --advertise-tags=tag:homelab"
  ]

  volumes {
    volume_name    = var.tailscale_data_vol
    container_path = "/var/lib/tailscale"
  }
  volumes {
    host_path      = "/dev/net/tun"
    container_path = "/dev/net/tun"
  }
}

# Get Tailscale IP directly with data source
data "external" "tailscale_ip" {
  depends_on = [docker_container.tailscale]

  # Using program with bash lets us handle errors and retries
  program = ["bash", "-c", <<-EOT
    # Give Tailscale time to authenticate
    for i in {1..6}; do
      # Try to get the Tailscale IP
      ip=$(ssh -i ${var.ssh_key_path} ${var.ssh_user}@${var.ssh_host} 'docker exec tailscale tailscale ip -4' 2>/dev/null | tr -d '[:space:]')

      # Check if we got a valid IP
      if [[ ! -z "$ip" && "$ip" != *"NeedsLogin"* ]]; then
        # Return the IP as JSON for Terraform
        echo "{\"ip\": \"$ip\"}"
        exit 0
      fi

      # Wait before retrying
      sleep 5
    done

    # If we reach here, we failed to get an IP
    # Return a fallback IP or error message
    echo "{\"ip\": \"${var.ssh_host}\"}" # Fallback to the server's IP
    >&2 echo "Failed to get Tailscale IP. Using server IP as fallback."
    >&2 ssh -i ${var.ssh_key_path} ${var.ssh_user}@${var.ssh_host} 'docker exec tailscale tailscale status'
  EOT
  ]
}


# Disable systemd-resolved to avoid DNS conflicts
resource "null_resource" "disable_systemd_resolved" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # Stop and disable systemd-resolved and its trigger sockets
      "sudo systemctl stop systemd-resolved systemd-resolved-monitor.socket systemd-resolved-varlink.socket || echo 'Failed to stop systemd-resolved'",
      "sudo systemctl disable systemd-resolved systemd-resolved-monitor.socket systemd-resolved-varlink.socket || echo 'Failed to disable systemd-resolved'",
      "sudo systemctl mask systemd-resolved systemd-resolved-monitor.socket systemd-resolved-varlink.socket || echo 'Failed to mask systemd-resolved'",

      # Create a backup of the current resolv.conf
      "sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d%H%M%S) || echo 'No backup created'",

      # Set up a basic resolv.conf with Google DNS
      "sudo rm -f /etc/resolv.conf || echo 'Failed to remove resolv.conf'",
      "echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf > /dev/null",
      "echo 'nameserver 8.8.4.4' | sudo tee -a /etc/resolv.conf > /dev/null",

      # Verify the changes
      "echo 'Current resolv.conf:'",
      "cat /etc/resolv.conf",

      # Ensure systemd doesn't recreate resolv.conf
      "if [ -d /etc/systemd/resolved.conf.d ]; then",
      "  echo 'DNSStubListener=no' | sudo tee /etc/systemd/resolved.conf.d/disable-stub-listener.conf > /dev/null || echo 'Could not create configuration'",
      "fi",

      # Verify systemd-resolved is stopped
      "systemctl status systemd-resolved --no-pager || echo 'systemd-resolved is not running'"
    ]
  }
}

# Create CoreDNS volume for configuration
resource "docker_volume" "coredns_config" { name = "coredns_config" }

# Set up CoreDNS configuration
resource "null_resource" "coredns_config" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.ssh_host
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/docker/volumes/coredns_config/_data",

      # Create the Corefile with admin interface disabled
      "sudo cat > /tmp/Corefile << 'EOL'",
      ".:53 {",
      "    # Forward most requests to external DNS",
      "    forward . 8.8.8.8 8.8.4.4 {",
      "        policy random",
      "        health_check 5s",
      "    }",
      "    # Enable DNS cache",
      "    cache 30",
      "    # Error logging",
      "    errors",
      "    # Enable prometheus metrics",
      "    prometheus :9153",
      "    # Load balance between A/AAAA replies",
      "    loadbalance",
      "}",
      "# Handle your custom domain",
      "${var.domain_name}:53 {",
      "    hosts {",
      "        ${var.ssh_host} *.${var.domain_name}",
      "        fallthrough",
      "    }",
      "    # Important: Forward queries that hosts plugin doesn't answer",
      "    forward . 8.8.8.8 8.8.4.4",
      "    # Enable DNS cache",
      "    cache 30",
      "    errors",
      "}",
      "EOL",
      "sudo cp /tmp/Corefile /var/lib/docker/volumes/coredns_config/_data/",
      "sudo chmod 644 /var/lib/docker/volumes/coredns_config/_data/Corefile",
      "rm /tmp/Corefile"
    ]
  }

  depends_on = [null_resource.disable_systemd_resolved]
}

# CoreDNS container
resource "docker_container" "coredns" {
  name  = "coredns"
  image = "coredns/coredns:latest"
  restart = "unless-stopped"

  # Port mappings
  ports {
    internal = 53
    external = 53
    protocol = "udp"
  }
  ports {
    internal = 53
    external = 53
    protocol = "tcp"
  }
  ports {
    internal = 9153
    external = 9153
  }

  volumes {
    volume_name    = docker_volume.coredns_config.name
    container_path = "/etc/coredns"
  }

  # Add critical environment variables
  env = [
    "GODEBUG=netdns=go",   # Use Go's DNS resolver
    "CORES=0",             # Use all available cores
  ]

  # Explicitly disable the built-in admin interface with command-line flags
  command = [
    "-conf",
    "/etc/coredns/Corefile",
    "-dns.port",
    "53"
  ]

  # Use host networking for proper DNS functionality
  network_mode = "host"

  # Change healthcheck to use DNS functionality instead of HTTP
  healthcheck {
    test         = ["CMD", "dig", "@127.0.0.1", "-p", "53", "localhost"]
    interval     = "10s"
    timeout      = "5s"
    start_period = "5s"
    retries      = 3
  }

  depends_on = [null_resource.coredns_config]
}

# Update the Cloudflare DNS record
resource "cloudflare_record" "homelab" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  value   = data.external.tailscale_ip.result.ip
  type    = "A"
  ttl     = 1
  proxied = false
}