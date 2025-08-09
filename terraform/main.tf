terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.107"
    }
  }
  backend "azurerm" {
    resource_group_name  = "yousma-rg"
    storage_account_name = "yousmastorage"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# --------------------
# Variables
# --------------------
variable "email_api_key" {
  description = "The email API key for the app"
  type        = string
}

variable "pipeline_sp_object_id" {
  description = "Object ID of the Azure DevOps pipeline's service principal"
  type        = string
}

# --------------------
# Resource Group
# --------------------
resource "azurerm_resource_group" "rg" {
  name     = "yousma-rg"
  location = "East US"
}

# --------------------
# Azure Container Registry
# --------------------
resource "azurerm_container_registry" "acr" {
  name                = "contactsaveracr1234"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

# --------------------
# Key Vault
# --------------------
resource "azurerm_key_vault" "kv" {
  name                        = "contactsavekv1234"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
}

data "azurerm_client_config" "current" {}

# Key Vault Access for pipeline service principal
resource "azurerm_key_vault_access_policy" "pipeline_sp" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.pipeline_sp_object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete"
  ]
}

# Store secret
resource "azurerm_key_vault_secret" "email_api_key" {
  name         = "EMAIL-API-KEY"
  value        = var.email_api_key
  key_vault_id = azurerm_key_vault.kv.id
}

# --------------------
# Container Apps Environment
# --------------------
resource "azurerm_container_app_environment" "cae" {
  name                = "contactsave-env"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# --------------------
# Container App
# --------------------
resource "azurerm_container_app" "app" {
  name                         = "contactsaveapp"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  identity {
    type = "SystemAssigned"
  }
  template {
    container {
      name   = "backend"
      image  = "${azurerm_container_registry.acr.login_server}/backend:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name        = "EMAIL_API_KEY"
        secret_name = "email-api-key"
      }
    }
    secret {
      name  = "email-api-key"
      value = azurerm_key_vault_secret.email_api_key.value
    }
  }
  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = "SystemAssigned"
  }
}

# --------------------
# Role Assignment - Container App can pull from ACR
# --------------------
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_container_app.app.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

