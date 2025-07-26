output "container_app_url" {
  value       = azurerm_container_app.app.latest_revision_fqdn
  description = "Public URL of the container app"
}
