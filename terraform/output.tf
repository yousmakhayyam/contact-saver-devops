
output "container_app_url" {
  description = "The FQDN of the Azure Container App"
  value       = azurerm_container_app.app.latest_revision_fqdn
}
