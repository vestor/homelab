output "glance_services" {
  description = "Service definitions for Glance dashboard"
  value = [
    {
      name         = "Palworld"
      group        = "Gaming"
      url          = "https://palworld.${var.domain_name}"
      icon         = ""
      internal_url = ""
      github_repo  = ""
    },
    {
      name         = "Pal Editor"
      group        = "Gaming"
      url          = "https://paledit.${var.domain_name}"
      icon         = ""
      internal_url = ""
      github_repo  = ""
    },
  ]
}
