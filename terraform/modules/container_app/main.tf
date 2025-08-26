resource "azurerm_user_assigned_identity" "acr_pull_identity" {
  name                = "acr-pull-identity"
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_role_assignment" "acr_pull_role" {
  principal_id         = azurerm_user_assigned_identity.acr_pull_identity.principal_id
  role_definition_name = "AcrPull"
  scope                = var.acr_id
}

resource "azurerm_container_app_environment" "env" {
  name                = "myproject-env"
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_container_app" "app" {
  name                        = var.app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.rg_name
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
      name    = "myapp"
      image   = "${var.acr_login_server}/moodly:${var.image_tag}"
      cpu     = 0.5
      memory  = "1.0Gi"

      env {
        name  = "WEBSITES_PORT"
        value = "80"
      }
    }
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.acr_pull_identity.id
  }

  tags = {
    environment = "dev"
  }

  depends_on = [
    azurerm_role_assignment.acr_pull_role
  ]
}
