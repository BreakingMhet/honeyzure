resource "random_integer" "random_int" {
  min = 1000
  max = 9999
}

resource "azurerm_resource_group" "rg_honey_test" {
  name     = "honey_test"
  location = "West Europe"
}

# Azure Analytics Workspace 

resource "azurerm_log_analytics_workspace" "monitor" {
  name                = "log-analytics-workspace"
  resource_group_name = azurerm_resource_group.rg_honey_test.name
  location            = azurerm_resource_group.rg_honey_test.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Azure Storage Account

resource "azurerm_storage_account" "sa_customers_data" {
  name                     = "customersdata${random_integer.random_int.id}"
  resource_group_name      = azurerm_resource_group.rg_honey_test.name
  location                 = azurerm_resource_group.rg_honey_test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Azure Container

resource "azurerm_storage_container" "cnt_customers_data" {
  name                  = "content"
  storage_account_name  = azurerm_storage_account.sa_customers_data.name
  container_access_type = "private"
}

# Azure Blob

resource "azurerm_storage_blob" "users_data" {
  name                   = "users_data.csv"
  storage_account_name   = azurerm_storage_account.sa_customers_data.name
  storage_container_name = azurerm_storage_container.cnt_customers_data.name
  type                   = "Block"
  access_tier            = "Cool"
  source                 = "users_data.csv"
}

# Monitor Diagnostic Settings for the blob (this enables loggin on the blob)

resource "azurerm_monitor_diagnostic_setting" "ds_blob" {
  name                       = split("/", azurerm_log_analytics_workspace.monitor.id)[length(split("/", azurerm_log_analytics_workspace.monitor.id)) - 1]
  target_resource_id         = "${azurerm_storage_account.sa_customers_data.id}/blobServices/default/"
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
}

# Action Group (it specifies the receiver of the alert)

variable "destination_email" {
  description = "Destination email for the alert"
}

resource "azurerm_monitor_action_group" "alert_email_action" {
  name                = "EmailAction"
  resource_group_name = azurerm_resource_group.rg_honey_test.name
  short_name          = "admin-mail"
  email_receiver {
    name                    = "sendtoUser"
    email_address           = var.destination_email
    use_common_alert_schema = true
  }
}


resource "azurerm_monitor_scheduled_query_rules_alert" "alert_blob" {
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
}