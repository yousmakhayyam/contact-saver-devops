# Azure DevOps Pipeline Troubleshooting Guide

## 🐛 Issues Fixed

### 1. **Terraform Backend Configuration Error**
**Problem:** Invalid backend configuration arguments (`arm_tenant_id`, `arm_client_id`, `arm_client_secret`)

**Root Cause:** The `TerraformTaskV1@0` task was trying to pass ARM service principal credentials as backend configuration parameters, but these aren't valid backend configuration options for the `azurerm` backend.

**Solution:**
- Removed hardcoded backend configuration from `terraform/main.tf`
- Let the Azure DevOps task handle backend configuration via the `backendServiceArm` parameter
- Backend configuration is now passed via the task parameters

### 2. **Variable Passing Issues**
**Problem:** Variables were being passed incorrectly using the `vars:` syntax

**Solution:**
- Changed from `vars:` and `args:` to `commandOptions:` parameter
- Properly formatted variables as `-var="key=value"` format
- Added proper Terraform plan step before apply

### 3. **ACR Credentials Missing**
**Problem:** `$(ACR_USERNAME)` and `$(ACR_PASSWORD)` variables were undefined

**Solution:**
- Added Azure CLI task to dynamically fetch ACR credentials
- Set pipeline variables with the retrieved credentials
- Ensures credentials are always current and available

### 4. **Resource Naming Conflicts**
**Problem:** Resource names might conflict with existing resources (global uniqueness required)

**Solution:**
- Updated Key Vault name to `contactkv123`
- Updated Web App name to `contact-webapp-123`
- ACR name already had suffix `contactsaveracr123`

## 🔧 Prerequisites Setup

### 1. **Azure Service Connection**
Ensure your Azure DevOps service connection `Azure-Yousma-Connection` has:
- Contributor permissions on the subscription
- Permission to create resources in the target resource groups

### 2. **ACR Service Connection**
Your `acr-connection` service connection should:
- Point to `contactsaveracr123.azurecr.io`
- Have admin credentials enabled
- Be properly configured in Azure DevOps

### 3. **Storage Account for Terraform State**
Ensure the following resources exist:
- Resource Group: `yousma-rg`
- Storage Account: `yousmastorage`
- Container: `tfstate`

If these don't exist, create them manually or run this Azure CLI command:
```bash
# Create resource group
az group create --name yousma-rg --location "East US"

# Create storage account
az storage account create \
  --name yousmastorage \
  --resource-group yousma-rg \
  --location "East US" \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name yousmastorage
```

## 🚀 Testing the Pipeline

### Expected Flow:
1. **Build Stage**: Builds Docker image and pushes to ACR
2. **Deploy Stage**: 
   - Installs Terraform
   - Initializes Terraform with Azure backend
   - Gets ACR credentials dynamically
   - Runs Terraform plan
   - Runs Terraform apply (auto-approved)

### Monitoring:
- Check the pipeline logs for each step
- Verify resources are created in Azure Portal
- Test the deployed web application
- Verify secrets are properly stored in Key Vault

## 🔍 Common Issues

### If Terraform Init Still Fails:
1. Verify service connection permissions
2. Check if the storage account exists and is accessible
3. Ensure the service principal has Storage Blob Data Contributor role

### If ACR Credentials Task Fails:
1. Verify ACR exists and admin is enabled
2. Check service connection has ACR permissions
3. Ensure ACR name is correct in variables

### If Resource Creation Fails:
1. Check for naming conflicts (resources with same names)
2. Verify permissions to create resources
3. Check subscription limits and quotas

## 📝 Pipeline Variables to Verify

Ensure these variables are correctly set in your pipeline:
- `azureServiceConnection`: Your Azure service connection name
- `dockerRegistryServiceConnection`: Your ACR service connection name
- `acrName`: Your ACR name (must be globally unique)
- `tfBackendRg`: Resource group for Terraform state
- `tfStorage`: Storage account for Terraform state
- `tfContainer`: Container name for Terraform state
- `tfKey`: Key for Terraform state file

## 🎯 Next Steps

After the pipeline runs successfully:
1. Verify all resources are created in Azure Portal
2. Test the web application URL
3. Check Key Vault for stored secrets
4. Verify container deployment in App Service
5. Test the complete CI/CD flow with a code change

The pipeline is now configured to handle the complete infrastructure provisioning and application deployment automatically on each commit to the main branch.