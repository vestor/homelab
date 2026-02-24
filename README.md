# Homelab Config

Terraform configs for my homelab — a single CoreOS (Fedora) machine running everything in Docker containers, managed over SSH.

## What's Running

**Media** — Jellyfin, Sonarr, Radarr, Bazarr, Prowlarr, qBittorrent, Jellyseerr, Byparr

**Home Automation** — Home Assistant, HyperHDR

**Gaming** — Palworld dedicated server, Pal Editor

**Monitoring** — Prometheus, Grafana, node_exporter, Uptime Kuma, Scrutiny, Speedtest Tracker

**Networking** — Traefik (reverse proxy), Tailscale (VPN), Cloudflare DNS

**Dashboard** — Glance (homepage), What's Up Docker

**Storage** — MergerFS (pooled disks), Scrutiny (disk health)

## How It Works

- All services deploy as Docker containers using a shared `service_template` module
- Traefik handles routing — each service gets a `*.pavish.online` subdomain
- Tailscale provides secure remote access
- Glance dashboard shows uptime, server metrics (via Grafana iframes), drive health, internet speed, network traffic, and release tracking
- Volumes are centralized in the `core` module and passed to consuming modules

## Structure

```
modules/
  core/              # Networks, volumes, socket proxy
  networking/        # Traefik, Tailscale, Cloudflare DNS, Speedtest, Uptime Kuma
  monitoring/        # Prometheus, Grafana, node_exporter
  media/             # Jellyfin, *arr stack, qBittorrent
  home_automation/   # Home Assistant, HyperHDR
  gaming/            # Palworld server
  dashboard/         # Glance, What's Up Docker
  storage/           # MergerFS, Scrutiny
  service_template/  # Reusable module for deploying a Docker service
templates/           # Glance config, Prometheus config, Grafana dashboards
```

## Setup

Needs Terraform, SSH access to the target machine, and a `terraform.tfvars` with your secrets (Cloudflare, Tailscale, Palworld, etc).

```bash
terraform init
terraform plan
terraform apply
```
