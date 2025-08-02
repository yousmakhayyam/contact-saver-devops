resource "azapi_update_resource" "patch_image_and_secret" {
  type        = "Microsoft.App/containerApps@2023-05-01"
  resource_id = azurerm_container_app.app.id

  body = jsonencode({
    properties = {
      template = {
        containers = [{
          name  = "placeholder"
          image = "${azurerm_container_registry.acr.login_server}/${var.container_image}:latest"
          env = [{
            name  = "EMAIL_API_KEY"
            secretRef = "EMAIL-API-KEY"
          }]
        }]
        secrets = [{
          name = "EMAIL-API-KEY"
          keyVaultUrl = azurerm_key_vault_secret.api_key.id
        }]
      }
    }
  })

  depends_on = [
    azurerm_container_app.app,
    azurerm_key_vault_secret.api_key,
    azurerm_key_vault_access_policy.app_policy,
    azurerm_role_assignment.acr_pull
  ]
}
