resource "azapi_update_resource" "patch_image_and_secret" {
  type      = "Microsoft.App/containerApps@2023-05-01"
  name      = azurerm_container_app.app.name
  parent_id = azurerm_container_app.app.id

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
                secretRef = "EMAIL-API-KEY"
              }
            ]
          }
        ]
        secrets = [
          {
            name         = "EMAIL-API-KEY"
            identity     = azurerm_user_assigned_identity.ua_identity.id
            keyVaultUrl  = azurerm_key_vault_secret.api_key.id
          }
        ]
      }
      configuration = {
        secrets = [
          {
            name         = "EMAIL-API-KEY"
            identity     = azurerm_user_assigned_identity.ua_identity.id
            keyVaultUrl  = azurerm_key_vault_secret.api_key.id
          }
        ]
      }
    }
  })

  response_export_values = ["properties.configuration"]
}
