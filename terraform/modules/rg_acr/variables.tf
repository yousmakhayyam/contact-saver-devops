variable "rg_name" {
  description = "Resource Group name"
  type        = string
}

variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
}

variable "location" {
  description = "Azure Region for resources"
  type        = string
}
