data "azuread_user" "entra_sqladmin" {
  user_principal_name = var.sql_admin
}

resource "azurerm_mssql_server" "sqlsrv_credit_cards" {
  name                = "creditcardsdata${random_integer.random_int.id}"
  resource_group_name = azurerm_resource_group.rg_honey_test.name
  location            = azurerm_resource_group.rg_honey_test.location
  version             = "12.0"

  identity {
    type = "SystemAssigned"
  }

  azuread_administrator {
    login_username              = data.azuread_user.entra_sqladmin.user_principal_name
    object_id                   = data.azuread_user.entra_sqladmin.object_id
    azuread_authentication_only = true
  }

  public_network_access_enabled = true
  depends_on                    = [azurerm_resource_group.rg_honey_test]
}

resource "azurerm_mssql_firewall_rule" "sqlsrv_firewall_rule" {
  name             = "AllowAllWindowsAzureIps"
  server_id        = azurerm_mssql_server.sqlsrv_credit_cards.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
  depends_on       = [azurerm_mssql_server.sqlsrv_credit_cards]
}

resource "azurerm_mssql_database" "sqldb_credit_cards" {
  name      = "CreditCardsData"
  server_id = azurerm_mssql_server.sqlsrv_credit_cards.id
  sku_name  = "Basic"

  storage_account_type = "Local"
  depends_on           = [azurerm_mssql_server.sqlsrv_credit_cards]
}

resource "azurerm_mssql_server_extended_auditing_policy" "sqlsrv_auditing_policy" {
  server_id              = azurerm_mssql_server.sqlsrv_credit_cards.id
  log_monitoring_enabled = true
  depends_on             = [azurerm_mssql_server.sqlsrv_credit_cards]
}

resource "azurerm_mssql_database_extended_auditing_policy" "sqldb_auditing_policy" {
  database_id            = azurerm_mssql_database.sqldb_credit_cards.id
  log_monitoring_enabled = true
  depends_on             = [azurerm_mssql_database.sqldb_credit_cards, azurerm_mssql_server_extended_auditing_policy.sqlsrv_auditing_policy]
}

resource "azurerm_monitor_diagnostic_setting" "ds_sqldb" {
  name                           = "ds_sqldb"
  target_resource_id             = azurerm_mssql_database.sqldb_credit_cards.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.monitor.id
  log_analytics_destination_type = "Dedicated"

  log {
    category = "SQLSecurityAuditEvents"
    enabled  = true
  }

  depends_on = [azurerm_mssql_database_extended_auditing_policy.sqldb_auditing_policy]
}

# Alert Rule

resource "azurerm_monitor_scheduled_query_rules_alert" "alert_sql" {
  name                = "alert_sql"
  location            = azurerm_resource_group.rg_honey_test.location
  resource_group_name = azurerm_resource_group.rg_honey_test.name

  action {
    action_group = [azurerm_monitor_action_group.alert_email_action.id]
  }
  data_source_id = azurerm_log_analytics_workspace.monitor.id
  description    = "Alert when the SQL DB is accessed"
  enabled        = true
  # Count all requests with server error result code grouped into 5-minute bins
  query       = <<-QUERY
AzureDiagnostics
| where client_ip_s != "Internal"
| extend RequesterUser = iff(session_server_principal_name_s == server_principal_name_s, tostring(session_server_principal_name_s), strcat(session_server_principal_name_s, ", ", server_principal_name_s))
| project TimeGenerated, RequesterUser, client_ip_s, ResourceGroup, LogicalServerName_s, database_name_s, action_name_s

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