resource "azapi_update_resource" "patch_image_and_secret" {
  type        = "Microsoft.App/containerApps@2023-05-01"
  resource_id = azurerm_container_app.app.id

  body = jsonencode({
    properties = {
      template = {
        containers = [
          {
            name  = "placeholder"
            image = "${azurerm_container_registry.acr.login_server}/${var.container_image}:latest"
            env = [
              {
                name      = "EMAIL-API-KEY"
                secretRef = "email-api-key"
              }
            ]
          }
        ]
      }
      configuration = {
        secrets = [
          {
            name        = "email-api-key"
            identity    = {
              resourceId = azurerm_user_assigned_identity.ua_identity.id
            }
            # ❌ FIXED: Use data block instead of resource to prevent secret deletion
            keyVaultUrl = data.azurerm_key_vault_secret.api_key.id
          }
        ]
      }
    }
  })

  response_export_values = ["properties.configuration"]
  depends_on = [
    azurerm_container_app.app,
    data.azurerm_key_vault_secret.api_key,
    azurerm_user_assigned_identity.ua_identity
  ]
}
