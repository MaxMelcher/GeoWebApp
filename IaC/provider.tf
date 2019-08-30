provider "azurerm" {
}

#Export the environment variables
#export ARM_ACCESS_KEY=$(az storage account keys list -n mamelchtf --query [0].value -o tsv)

terraform {
  backend "azurerm" {
    storage_account_name = "mamelchtf"
    container_name       = "tflfx"
    key                  = "prod.terraform.tfstate"
  }
}

