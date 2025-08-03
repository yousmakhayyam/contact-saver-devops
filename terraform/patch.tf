resource "azapi_update_resource" "patch_image_and_secret" {
  type        = "Microsoft.App/containerApps@2023-05-01"
  resource_id = azurerm_container_app.app.id
  body        = jsonencode({
    properties = {
      template = {
        containers = [
          {
            name  = "contact-saver"
            image = "${azurerm_container_registry.acr.login_server}/contact-saver:latest"
            env   = [
              {
                name      = "EMAIL_API_KEY"       # 👈 ENV VAR used by app
                secretRef = "email-api-key"       # 👈 must match key vault secret name
              }
            ]
          }
        ]
        scale = {
          minReplicas = 1
          maxReplicas = 1
        }
      }
      configuration = {
        secrets = [
          {
            name  = "email-api-key"              # 👈 FIXED: all lowercase
            value = var.email_api_key
          }
        ]
      }
    }
  })
}
