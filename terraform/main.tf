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

# 🔷 ACR
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# 🔷 App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "B1"
}

# 🔷 Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
}

# 🔐 Access Policy for Terraform (so it can create secrets)
resource "azurerm_key_vault_access_policy" "terraform_spn_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List"]
}

# 🔐 Store API Key Secret
resource "azurerm_key_vault_secret" "api_key" {
  name         = "EMAIL-API-KEY"
  value        = var.email_api_key
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_spn_policy]
}

# 🌐 Linux Web App
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

  depends_on = [azurerm_key_vault_secret.api_key]
}

# 🔐 Access Policy for Web App Identity (to read secret at runtime)
resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app.identity[0].principal_id

  secret_permissions = ["Get"]
}
