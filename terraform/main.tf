
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

# Defining the resource group that all other resources will reside in.
resource "azurerm_resource_group" "rg" {
  name     = "yousma-khayam-rg"
  location = "East US"
}

# The Azure Container Registry. This is where your Docker images are stored.
resource "azurerm_container_registry" "acr" {
  name                = "myprojectacr1234"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

# This data source waits for the ACR repository to be available before deploying the app.
# It makes the deployment more reliable than a simple 'sleep' command.
data "azurerm_container_registry_repository" "moodly_repo" {
  name                  = "moodly"
  container_registry_id = azurerm_container_registry.acr.id
  depends_on            = [azurerm_container_registry.acr]
}

# This user-assigned identity is created for the Container App to pull images from ACR.
resource "azurerm_user_assigned_identity" "acr_pull_identity" {
  name                = "acr-pull-identity"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# The AcrPull role assignment for the user-assigned identity. 
# This gives the Container App permission to pull images from the ACR.
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
      image  = "${azurerm_container_registry.acr.login_server}/moodly:latest"
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

  # This depends_on block is crucial. It ensures the container app is only deployed after
  # the AcrPull role is assigned and the Docker image repository is confirmed to exist.
  depends_on = [
    azurerm_role_assignment.acr_pull_role,
    data.azurerm_container_registry_repository.moodly_repo,
  ]
}
