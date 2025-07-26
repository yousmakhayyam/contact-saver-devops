terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

#############################
# 🔧 Variables Declaration  #
#############################

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "acr_name" {
  type        = string
  description = "Azure Container Registry name"
}

variable "web_app_name" {
  type        = string
  description = "Azure Container App name"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault name"
}

variable "email_api_key" {
  type        = string
  description = "Email API Key to store in Key Vault"
  sensitive   = true
}

variable "acr_admin_username" {
  type        = string
  description = "ACR admin username"
}

variable "acr_admin_password" {
  type        = string
  description = "ACR admin password"
  sensitive   = true
}

variable "container_image" {
  type        = string
  description = "Docker image name"
}

variable "app_service_plan_name" {
  type        = string
  description = "App Service Plan name"
}

#############################
# 🔧 Infrastructure         #
#############################

# 🔷 ACR
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

# 🔐 Access Policy for Terraform SPN
resource "azurerm_key_vault_access_policy" "terraform_spn_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List"]
}

# 🔐 Store API Key Secret in Key Vault
resource "azurerm_key_vault_secret" "api_key" {
  name         = "EMAIL-API-KEY"
  value        = var.email_api_key
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_spn_policy]
}

# 🌐 Container App Environment
resource "azurerm_container_app_environment" "env" {
  name                = "${var.web_app_name}-env"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# 🌐 Azure Container App
resource "azurerm_container_app" "app" {
  name                         = var.web_app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.resource_group_name
  location                     = var.location

  revision_mode = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = var.acr_admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = var.acr_admin_password
  }

  secret {
    name  = "email-api-key"
    value = azurerm_key_vault_secret.api_key.value
  }

  template {
    container {
      name   = "contact-app"
      image  = "${azurerm_container_registry.acr.login_server}/${var.container_image}:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name        = "EMAIL_API_KEY"
        secret_name = "email-api-key"
      }

      env {
        name  = "WEBSITES_PORT"
        value = "3000"
      }
    }
  }

  depends_on = [azurerm_key_vault_secret.api_key]
}

# 🔐 Access Policy for Container App Identity
resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.app.identity[0].principal_id

  secret_permissions = ["Get"]
}
