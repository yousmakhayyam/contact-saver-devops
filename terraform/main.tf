provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "yousma1-rg"  # lowercase for consistency
  location = "East US"
}

resource "azurerm_container_registry" "acr" {
  name                = "myprojectacr1234"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_app_service_plan" "plan" {
  name                = "myproject-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    tier = "Free"
    size = "F1"
  }

  kind     = "Linux"
  reserved = true
}

resource "azurerm_linux_web_app" "webapp" {
  name                = "myproject-webapp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_app_service_plan.plan.id

  site_config {
    application_stack {
      docker_image_name        = "myprojectacr1234.azurecr.io/myapp:latest"
      docker_registry_url      = "https://${azurerm_container_registry.acr.login_server}"
      docker_registry_username = azurerm_container_registry.acr.admin_username
      docker_registry_password = azurerm_container_registry.acr.admin_password
    }
  }

  app_settings = {
    "WEBSITES_PORT" = "80"
  }
}
