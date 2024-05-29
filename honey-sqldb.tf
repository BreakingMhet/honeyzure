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

resource "azurerm_mssql_database" "sqldb_credit_cards" {
  name                = "CreditCardsData"
  server_id           = azurerm_mssql_server.sqlsrv_credit_cards.id
  sku_name            = "Basic"
  depends_on          = [azurerm_mssql_server.sqlsrv_credit_cards]
}