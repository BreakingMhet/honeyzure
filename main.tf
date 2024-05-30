terraform {
  required_version = ">= 1.6.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
  }
}

provider "azuread" {}

provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}

provider "random" {}

resource "random_integer" "random_int" {
  min = 1000
  max = 9999
}


resource "azurerm_resource_group" "rg_honey_test" {
  name     = "honey_test"
  location = "Italy North"
}

# Azure Analytics Workspace 

resource "azurerm_log_analytics_workspace" "monitor" {
  name                = "log-analytics-workspace"
  resource_group_name = azurerm_resource_group.rg_honey_test.name
  location            = azurerm_resource_group.rg_honey_test.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  depends_on          = [azurerm_resource_group.rg_honey_test]
}
