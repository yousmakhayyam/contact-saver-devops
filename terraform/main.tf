terraform {
  backend "azurerm" {
    resource_group_name  = "yousma-rg"
    storage_account_name = "yousmastorage"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "adc9f320-e56e-45b1-845e-c73484745fc8"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "yousma-khayam-rg"
  location = "East US"
}

resource "azurerm_key_vault" "kv" {
  name                 = "myproject-kv"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  tenant_id            = data.azurerm_client_config.current.tenant_id
  sku_name             = "standard"
}

variable "db_password" {
  type        = string
  description = "Database password secret from pipeline variable"
}

resource "azurerm_key_vault_access_policy" "terraform_executor_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
  ]
}

resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = "20548baa-5960-4466-9ca1-2cf51d3954e8"

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
  ]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "DbPassword"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.app_policy,
    azurerm_key_vault_access_policy.terraform_executor_policy
  ]
}

resource "azurerm_container_registry" "acr" {
  name                = "myprojectacr1234"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true # <-- CORRECTED: Admin account is now enabled here
}

resource "azurerm_user_assigned_identity" "acr_pull_identity" {
  name                = "acr-pull-identity"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "acr_pull_role" {
  principal_id         = azurerm_user_assigned_identity.acr_pull_identity.principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

resource "azurerm_container_app_environment" "env" {
  name                = "myproject-env"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_container_app" "app" {
  name                         = "myproject-webapp"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.acr_pull_identity.id]
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "myapp"
      image  = "${azurerm_container_registry.acr.login_server}/moodly:${var.image_tag}"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "WEBSITES_PORT"
        value = "80"
      }
    }
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.acr_pull_identity.id
  }

  tags = {
    environment = "dev"
  }

  depends_on = [
    azurerm_role_assignment.acr_pull_role
  ]
}

# ---- NEW CODE START ----
# Store ACR username in Key Vault
resource "azurerm_key_vault_secret" "acr_username" {
  name         = "AcrUsername"
  value        = azurerm_container_registry.acr.admin_username
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.terraform_executor_policy,
    azurerm_key_vault_access_policy.app_policy
  ]
}

# Store ACR password in Key Vault
resource "azurerm_key_vault_secret" "acr_password" {
  name         = "AcrPassword"
  value        = azurerm_container_registry.acr.admin_password
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.terraform_executor_policy,
    azurerm_key_vault_access_policy.app_policy
  ]
}
# ---- NEW CODE END ----

variable "image_tag" {
  type        = string
  description = "Tag of the Docker image to deploy"
  default     = "latest"
}