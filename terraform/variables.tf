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
