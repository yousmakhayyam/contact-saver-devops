resource "azurerm_key_vault" "kv" {
  name                 = var.kv_name
  location             = var.location
  resource_group_name  = var.rg_name
  tenant_id            = var.tenant_id
  sku_name             = "standard"
}

resource "azurerm_key_vault_access_policy" "terraform_executor_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = var.tenant_id
  object_id    = var.executor_object_id

  secret_permissions = ["Get","List","Set","Delete"]
}

resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = var.tenant_id
  object_id    = var.app_object_id

  secret_permissions = ["Get","List","Set","Delete"]
}

resource "azurerm_key_vault_secret" "acr_username" {
  name         = "AcrUsername"
  value        = var.acr_username
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "acr_password" {
  name         = "AcrPassword"
  value        = var.acr_password
  key_vault_id = azurerm_key_vault.kv.id
}

output "kv_id" {
  value = azurerm_key_vault.kv.id
}
