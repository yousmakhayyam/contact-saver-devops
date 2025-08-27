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

variable "image_tag" {
  type        = string
  description = "Tag of the Docker image to deploy"
  default     = "latest"
}

module "rg_acr" {
  source   = "./modules/rg_acr"
  rg_name  = "yousma-khayam-rg"
  acr_name = "myprojectacr1234"
  location = "East US"
}

module "keyvault" {
  source            = "./modules/keyvault"
  rg_name           = module.rg_acr.rg_name
  kv_name           = "myproject-kv"
  location          = module.rg_acr.rg_location
  tenant_id         = data.azurerm_client_config.current.tenant_id
  executor_object_id = data.azurerm_client_config.current.object_id
  app_object_id     = "20548baa-5960-4466-9ca1-2cf51d3954e8"
  acr_username      = module.rg_acr.acr_admin_username
  acr_password      = module.rg_acr.acr_admin_password
}

module "container_app" {
  source           = "./modules/container_app"
  rg_name          = module.rg_acr.rg_name
  location         = module.rg_acr.rg_location
  acr_id           = module.rg_acr.acr_id
  acr_login_server = module.rg_acr.acr_login_server
  app_name         = "myproject-webapp"
  image_tag        = var.image_tag
}
