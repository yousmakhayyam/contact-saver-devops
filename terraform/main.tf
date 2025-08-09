terraform {
  required_version = ">=1.4.0"

  backend "azurerm" {
    resource_group_name  = "yousma-rg"
    storage_account_name = "yousmastorage"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.107"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "email_api_key" {
  description = "The email API key for the app"
  type        = string
}

# Reference existing resource group (prevents deletion issue)
data "azurerm_resource_group" "rg" {
  name = "yousma-rg"
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "contactsaveracr1234"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                = "yousmakv"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}

data "azurerm_client_config" "current" {}

# Access policy for pipeline service principal
resource "azurerm_key_vault_access_policy" "pipeline_sp" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.pipeline_sp_object_id

  secret_permissions = ["Get", "List", "Set"]
}

# Store secret in Key Vault (lowercase to avoid naming issues)
resource "azurerm_key_vault_secret" "email_api_key" {
  name         = "email-api-key"
  value        = var.email_api_key
  key_vault_id = azurerm_key_vault.kv.id
}

# Container App Environment
resource "azurerm_container_app_environment" "cae" {
  name                = "contactsaver-env"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Container App with ACR pull & Key Vault secret
resource "azurerm_container_app" "app" {
  name                         = "contactsaver-app"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = data.azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = "SystemAssigned"
  }

  template {
    container {
      name   = "contactsaver-container"
      image  = "${azurerm_container_registry.acr.login_server}/contactsaver:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "EMAIL_API_KEY"
        secret_name = "email-api-key"
      }
    }
  }

  secret {
    name  = "email-api-key"
    value = azurerm_key_vault_secret.email_api_key.value
  }
}

# Give Container App identity ACR pull permission
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = azurerm_container_app.app.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}
