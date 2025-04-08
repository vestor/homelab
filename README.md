# Homelab Infrastructure as Code

This repository contains Terraform configurations to deploy and manage a comprehensive homelab environment. The infrastructure is designed to run on a CoreOS machine using Docker containers with a focus on media management, home automation, and system monitoring.

## Features

- **Storage Management**:
    - MergerFS for unified storage across multiple disks
    - Disk health monitoring with custom scripts and systemd timers
- **Reverse Proxy**:
    - Traefik for service routing with hostname-based access
- **Media Management**:
    - **Jellyfin**: Media server with transcoding capabilities
    - **Sonarr**: TV show management and automation
    - **Radarr**: Movie management and automation
    - **Bazarr**: Subtitle management for Sonarr and Radarr
    - **Prowlarr**: Indexer management for *arr applications
    - **qBittorrent**: Download client
    - **Jellyseerr**: Media request and management
- **Home Automation**:
    - **Home Assistant**: Smart home control and automation
    - **HyperHDR**: Ambient lighting control
- **System Management**:
    - **Tailscale**: Secure remote access
    - **Homepage**: Unified dashboard for system monitoring and service access
    - **Watchtower**: Automatic updates for Docker containers
    - **WhatSup Docker**: Docker container monitoring
    - **CoreDNS**: DNS server for local network

## Prerequisites

- A CoreOS or similar Linux machine with SSH access
- Docker installed on the target machine
- Terraform v1.0 or higher installed on your local machine
- SSH key access to the target machine

## Getting Started

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/homelab-infrastructure.git
   cd homelab-infrastructure