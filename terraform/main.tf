# ✅ FIXED Terraform Code (main.tf) - Error-free with identity patching

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.96.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.12.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
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
  subscription_id = "adc9f320-e56e-45b1-845e-c73484745fc8"
}

data "azurerm_client_config" "current" {}

variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "acr_name"            { type = string }
variable "web_app_name"        { type = string }
variable "key_vault_name"      { type = string }

variable "email_api_key" {
  type      = string
  sensitive = true
}

variable "container_image" { type = string }

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

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
  secret_permissions =  ["Get", "Set", "List"]
}

data "azurerm_key_vault_secret" "api_key" {
  name         = "email-api-key"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_container_app_environment" "env" {
  name                = "contact-env"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_container_app" "app" {
  name                         = var.web_app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = "backend"
      image  = "${azurerm_container_registry.acr.login_server}/${var.container_image}:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "EMAIL_API_KEY"
        value = data.azurerm_key_vault_secret.api_key.value
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.app.identity[0].principal_id
  depends_on           = [azurerm_container_app.app]
}

resource "time_sleep" "wait_for_identity" {
  depends_on = [azurerm_role_assignment.acr_pull]
  create_duration = "30s"
}

resource "azapi_update_resource" "patch_registry" {
  type        = "Microsoft.App/containerApps@2023-05-01"
  resource_id = azurerm_container_app.app.id
  depends_on  = [time_sleep.wait_for_identity]

  body = jsonencode({
    properties = {
      configuration = {
        registries = [{
          server   = azurerm_container_registry.acr.login_server
          identity = "SystemAssigned"
        }]
      }
    }
  })
}

output "container_app_url" {
  value = azurerm_container_app.app.latest_revision_fqdn
}