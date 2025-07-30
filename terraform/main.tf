provider "azurerm" {
  features {
    container_app {
      auto_upgrade_minor_version = true
    }
  }
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

# ✅ NEW: Container App Environment
resource "azurerm_container_app_environment" "env" {
  name                = "${var.web_app_name}-env"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# ✅ NEW: Container App (replacing Linux Web App)
resource "azurerm_container_app" "app" {
  name                         = var.web_app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.resource_group_name
  location                     = var.location
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = "contact-saver"
      image  = "${azurerm_container_registry.acr.login_server}/${var.container_image}:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name        = "EMAIL_API_KEY_SETTING"
        secret_name = "EMAIL-API-KEY"
      }
    }

    secret {
      name  = "EMAIL-API-KEY"
      value = azurerm_key_vault_secret.api_key.value
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "auto"
  }

  depends_on = [azurerm_key_vault_secret.api_key]
}

# ✅ NEW: Grant access to secrets
resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = azurerm_container_app.app.identity[0].tenant_id
  object_id    = azurerm_container_app.app.identity[0].principal_id

  secret_permissions = ["Get"]
}

# ✅ Corrected output
output "container_app_url" {
  value       = azurerm_container_app.app.latest_revision_fqdn
  description = "Public URL of the deployed container app"
}
