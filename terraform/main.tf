provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "acr_name" { type = string }
variable "web_app_name" { type = string }
variable "key_vault_name" { type = string }

variable "email_api_key" {
  type      = string
  sensitive = true
}

variable "acr_admin_user" { type = string }

variable "acr_admin_pass" {
  type      = string
  sensitive = true
}

variable "container_image" { type = string }
variable "app_service_plan_name" { type = string }

# ACR
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
}

# Terraform access to Key Vault
resource "azurerm_key_vault_access_policy" "terraform_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List"]
}

# Store API Key
resource "azurerm_key_vault_secret" "api_key" {
  name         = "EMAIL-API-KEY"
  value        = var.email_api_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.terraform_policy]
}

# App Service Plan
resource "azurerm_service_plan" "app_plan" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "F1"
}

# ✅ Updated to use azurerm_linux_web_app instead of deprecated azurerm_app_service
resource "azurerm_linux_web_app" "web_app" {
  name                = var.web_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.app_plan.id

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "DOCKER_REGISTRY_SERVER_URL"          = azurerm_container_registry.acr.login_server
    "DOCKER_REGISTRY_SERVER_USERNAME"     = var.acr_admin_user
    "DOCKER_REGISTRY_SERVER_PASSWORD"     = var.acr_admin_pass
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "WEBSITES_PORT"                       = "3000"
    "EMAIL_API_KEY_SETTING"               = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.api_key.id})"
  }

  site_config {
    linux_fx_version = "DOCKER|${azurerm_container_registry.acr.login_server}/${var.container_image}:latest"
    always_on        = true
  }

  depends_on = [azurerm_key_vault_secret.api_key]
}

# Key Vault Access for Web App
resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = azurerm_linux_web_app.web_app.identity[0].tenant_id
  object_id    = azurerm_linux_web_app.web_app.identity[0].principal_id

  secret_permissions = ["Get"]
}

# ✅ Corrected output attribute
output "web_app_url" {
  value       = azurerm_linux_web_app.web_app.default_hostname
  description = "Public URL of the web app"
}
