# Home Automation module outputs

output "automation_service_urls" {
  description = "URLs for all home automation services"
  value = {
    homeassistant = module.homeassistant.service_url
    hyperhdr      = module.hyperhdr.service_url
  }
}

output "container_names" {
  description = "Names of deployed home automation containers"
  value = {
    homeassistant = module.homeassistant.container_name
    hyperhdr      = module.hyperhdr.container_name
  }
}

output "hyperhdr_image_info" {
  description = "Information about the custom HyperHDR image"
  value = "custom-hyperhdr:latest"
}

output "glance_services" {
  description = "Service definitions for Glance dashboard"
  value = [
    {
      name         = "Home Assistant"
      group        = "Home Automation"
      url          = "https://homeassistant.${var.domain_name}"
      icon         = "si:homeassistant"
      internal_url = "http://homeassistant:8123"
      github_repo  = "home-assistant/core"
    },
    {
      name         = "HyperHDR"
      group        = "Home Automation"
      url          = "https://hyperhdr.${var.domain_name}"
      icon         = ""
      internal_url = ""
      github_repo  = ""
    },
  ]
}
