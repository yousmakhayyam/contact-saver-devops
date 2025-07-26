terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# VARIABLES
variable "resource_group_name" {}
variable "location" {}
variable "acr_name" {}
variable "app_service_plan_name" {}
variable "web_app_name" {}
variable "key_vault_name" {}
variable "email_api_key" {}
variable "acr_admin_username" {}
variable "acr_admin_password" {}
variable "container_image" {}

# Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Updated App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "B1"
}

# Key Vault (fixed deprecated field)
resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
}

# Store API Key Secret in Key Vault
resource "azurerm_key_vault_secret" "api_key" {
  name         = "EMAIL-API-KEY"
  value        = var.email_api_key
  key_vault_id = azurerm_key_vault.kv.id
}

# Linux Web App for Containers
resource "azurerm_linux_web_app" "app" {
  name                = var.web_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.asp.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    linux_fx_version = "DOCKER|${azurerm_container_registry.acr.login_server}/${var.container_image}:latest"
    always_on        = true
  }

  app_settings = {
    WEBSITES_PORT                    = "3000"
    EMAIL_API_KEY                    = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.api_key.id})"
    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = var.acr_admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = var.acr_admin_password
  }

  depends_on = [
    azurerm_key_vault_secret.api_key
  ]
}

# Key Vault Access Policy (fix: identity[0] and capital "Get")
resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app.identity[0].principal_id

  secret_permissions = ["Get"]
}
