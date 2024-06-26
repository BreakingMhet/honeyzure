# Azure Storage Account
resource "azurerm_storage_account" "sa_customers_data" {
  count                    = var.enable_storage ? 1 : 0
  name                     = "customersdata${random_integer.random_int.id}"
  resource_group_name      = azurerm_resource_group.rg_honey_test.name
  location                 = azurerm_resource_group.rg_honey_test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on               = [azurerm_resource_group.rg_honey_test]
}

# Azure Container
resource "azurerm_storage_container" "cnt_customers_data" {
  count                 = var.enable_storage ? 1 : 0
  name                  = "content"
  storage_account_name  = azurerm_storage_account.sa_customers_data[0].name
  container_access_type = "private"
  depends_on            = [azurerm_storage_account.sa_customers_data]
}

# Azure Blob
resource "azurerm_storage_blob" "users_data" {
  count                  = var.enable_storage ? 1 : 0
  name                   = "users_data.csv"
  storage_account_name   = azurerm_storage_account.sa_customers_data[0].name
  storage_container_name = azurerm_storage_container.cnt_customers_data[0].name
  type                   = "Block"
  access_tier            = "Cool"
  source                 = "users_data.csv"
  depends_on             = [azurerm_storage_container.cnt_customers_data]
}

# Monitor Diagnostic Settings for the blob (this enables logging on the blob)
resource "azurerm_monitor_diagnostic_setting" "ds_blob" {
  count                      = var.enable_storage ? 1 : 0
  name                       = split("/", azurerm_log_analytics_workspace.monitor.id)[length(split("/", azurerm_log_analytics_workspace.monitor.id)) - 1]
  target_resource_id         = "${azurerm_storage_account.sa_customers_data[0].id}/blobServices/default/"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.monitor.id

  log {
    category = "StorageRead"
    enabled  = true
  }
  log {
    category = "StorageWrite"
    enabled  = true
  }
  log {
    category = "StorageDelete"
    enabled  = true
  }
  depends_on = [azurerm_storage_account.sa_customers_data]
}

# Alert Rule
resource "azurerm_monitor_scheduled_query_rules_alert" "alert_blob" {
  count               = var.enable_storage ? 1 : 0
  name                = "alert_blob"
  location            = azurerm_resource_group.rg_honey_test.location
  resource_group_name = azurerm_resource_group.rg_honey_test.name

  action {
    action_group = [azurerm_monitor_action_group.alert_email_action.id]
  }
  data_source_id = azurerm_log_analytics_workspace.monitor.id
  description    = "Alert when the blob is accessed"
  enabled        = true
  # Count all requests with server error result code grouped into 5-minute bins
  query       = <<-QUERY
  StorageBlobLogs 
| where isnotempty(RequesterUpn) 
| project RequesterUpn,CallerIpAddress, Category, OperationName, _ResourceId, StatusText
  QUERY
  severity    = 1
  frequency   = 5
  time_window = 30
  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
  depends_on = [azurerm_monitor_action_group.alert_email_action]
}
