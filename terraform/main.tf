provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# 🔧 Variables
variable "resource_group_name" {}
variable "location" {}
variable "acr_name" {}
variable "key_vault_name" {}
variable "web_app_name" {}
variable "app_service_plan_name" {}
variable "app_service_sku" {
  default = "B1"
}
variable "acr_admin_username" {}
variable "acr_admin_password" {}
variable "app_secret_value" {
  sensitive = true
}

# 🔹 Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 🔹 Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# 🔐 Azure Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
}

# 🔐 Access Policy for Terraform SPN
resource "azurerm_key_vault_access_policy" "terraform_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List"]
}

# 🔐 Store App Secret
resource "azurerm_key_vault_secret" "app_secret" {
  name         = "APP-SECRET"
  value        = var.app_secret_value
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}

# 🔷 App Service Plan
resource "azurerm_app_service_plan" "asp" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Basic"
    size = var.app_service_sku
  }
}

# 🌐 Web App for Containers
resource "azurerm_linux_web_app" "webapp" {
  name                = var.web_app_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_app_service_plan.asp.id

  site_config {
    application_stack {
      docker_image_name   = "${azurerm_container_registry.acr.login_server}/your-app-image:latest"
      docker_registry_url = azurerm_container_registry.acr.login_server
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "DOCKER_REGISTRY_SERVER_USERNAME" = var.acr_admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD" = var.acr_admin_password
    "SECRET_FROM_VAULT"               = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.app_secret.id})"
    "WEBSITES_PORT"                   = "3000"
  }

  depends_on = [azurerm_key_vault_secret.app_secret]
}

# 🔐 Key Vault Access for Web App
resource "azurerm_key_vault_access_policy" "webapp_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.webapp.identity[0].principal_id

  secret_permissions = ["Get"]
}
