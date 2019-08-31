provider "azurerm" {
}

#Export the environment variables
#WSL:         export ARM_ACCESS_KEY=$(az storage account keys list -n mamelchtf --query [0].value -o tsv)
#Powershell:  $env:ARM_ACCESS_KEY=$(az storage account keys list -n mamelchtf --query [0].value -o tsv)
terraform {
  backend "azurerm" {
    storage_account_name = "mamelchtf"
    container_name       = "tflfx"
    key                  = "prod.terraform.tfstate"
  }
}

