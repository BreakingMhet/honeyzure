# Cosmos DB Account

resource "azurerm_cosmosdb_account" "cdb_account" {
  name                = "creditcardsnum${random_integer.random_int.id}"
  resource_group_name = azurerm_resource_group.rg_honey_test.name
  location            = azurerm_resource_group.rg_honey_test.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg_honey_test.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableTable"
  }

  enable_automatic_failover = false
  depends_on                = [azurerm_resource_group.rg_honey_test]
}

# Cosmos DB Table

resource "azurerm_cosmosdb_table" "honey_table" {
  name                = "CreditCardNumbers"
  resource_group_name = azurerm_resource_group.rg_honey_test.name
  account_name        = azurerm_cosmosdb_account.cdb_account.name
  throughput          = 400 #This is the minimum
  depends_on          = [azurerm_cosmosdb_account.cdb_account]
}

# Monitor Diagnostic Settings for the Cosmos' Account

resource "azurerm_monitor_diagnostic_setting" "ds_cosmos" {
  name                           = "ds_cosmos"
  target_resource_id             = azurerm_cosmosdb_account.cdb_account.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.monitor.id
  log_analytics_destination_type = "Dedicated"
  log {
    category = "DataPlaneRequests"
    enabled  = true
  }
  log {
    category = "ControlPlaneRequests"
    enabled  = true
  }
  depends_on = [azurerm_cosmosdb_account.cdb_account]
}