

locals {
  resource_group_name = "${var.project}-rg"
  server_name         = "${var.project}-${var.environment}-postgres-c"
}


resource "azurerm_postgresql_flexible_server" "main" {
  name                          = local.server_name
  resource_group_name           = local.resource_group_name
  location                      = var.location
  version                       = "15"
  delegated_subnet_id           = var.database_subnet_id
  private_dns_zone_id           = var.postgres_dns_zone_id
  public_network_access_enabled = false
  administrator_login           = "docbridge_user"
  administrator_password        = var.db_password
  zone                          = "1"

  storage_mb = 32768
  sku_name   = "B_Standard_B2s"

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false



  tags = var.tags
}


resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "docbridge_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}


resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "${var.project}-${var.environment}-postgres-diag"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = var.workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  enabled_log {
    category = "PostgreSQLFlexQueryStoreRuntime"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "UUID-OSSP"
}
