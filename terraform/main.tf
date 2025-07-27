# main.tf

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# 🌍 Variables
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "acr_name" {
  type = string
}

variable "web_app_name" {
  type = string
}

variable "key_vault_name" {
  type = string
}

variable "email_api_key" {
  type        = string
  sensitive   = true
}

variable "acr_admin_username" {
  type = string
}

variable "acr_admin_password" {
  type        = string
  sensitive   = true
}

variable "container_image" {
  type = string
}

variable "app_service_plan_name" { # This variable is now relevant and used
  type = string
}

# 📦 ACR
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# 🔐 Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
}

resource "azurerm_key_vault_access_policy" "terraform_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List"]
}

resource "azurerm_key_vault_secret" "api_key" {
  name         = "EMAIL-API-KEY"
  value        = var.email_api_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.terraform_policy]
}

# 🌐 App Service Plan (for Azure Web App for Containers)
resource "azurerm_app_service_plan" "app_plan" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "Linux" # Important for Linux containers
  reserved            = true    # Required for Linux plans

  sku {
    tier = "Basic"
    size = "B1" # Or S1, P1V2 etc.
  }
}

# 🚀 Azure Web App for Containers
resource "azurerm_app_service" "web_app" {
  name                = var.web_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.app_plan.id

  # Configure Web App to pull from ACR using admin credentials
  app_settings = {
    "DOCKER_REGISTRY_SERVER_URL"      = azurerm_container_registry.acr.login_server
    "DOCKER_REGISTRY_SERVER_USERNAME" = var.acr_admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD" = var.acr_admin_password
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false" # For stateless containers
    "WEBSITES_PORT" = "3000" # Your app listens on 3000
    # Example of referencing a Key Vault secret directly in App Settings (requires Managed Identity)
    "EMAIL_API_KEY_SETTING" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.api_key.id})"
  }

  site_config {
    # This sets the initial image, but AzureWebAppContainer@1 task will update it
    linux_fx_version = "DOCKER|${azurerm_container_registry.acr.login_server}/${var.container_image}:latest"
    always_on        = true
  }

  identity {
    type = "SystemAssigned" # Enable Managed Identity for the Web App
  }
  depends_on = [azurerm_key_vault_secret.api_key]
}

# 🔐 App Access to Key Vault (for Web App Managed Identity)
resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = azurerm_app_service.web_app.identity[0].tenant_id
  object_id    = azurerm_app_service.web_app.identity[0].principal_id

  secret_permissions = ["Get"] # Grant Get permission for the Web App to read secrets
}

output "web_app_url" {
  value       = azurerm_app_service.web_app.default_host_name
  description = "Public URL of the web app"
}