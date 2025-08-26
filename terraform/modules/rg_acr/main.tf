resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

data "azurerm_container_registry" "acr_creds" {
  name                = azurerm_container_registry.acr.name
  resource_group_name = azurerm_resource_group.rg.name
}

output "rg_name" {
  value = azurerm_resource_group.rg.name
}

output "rg_location" {
  value = azurerm_resource_group.rg.location
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_id" {
  value = azurerm_container_registry.acr.id
}

output "acr_admin_username" {
  value = data.azurerm_container_registry.acr_creds.admin_username
}

output "acr_admin_password" {
  value = data.azurerm_container_registry.acr_creds.admin_password
}
