

locals {
  resource_group_name = "${var.project}-rg"
  redis_name          = "${var.project}-${var.environment}-redis"
}


resource "azurerm_redis_cache" "main" {
  name                          = local.redis_name
  location                      = var.location
  resource_group_name           = local.resource_group_name
  capacity                      = 1
  family                        = "C"
  sku_name                      = "Basic"
  enable_non_ssl_port           = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  redis_configuration {
    maxmemory_reserved = 2
    maxmemory_delta    = 2
    maxmemory_policy   = "allkeys-lru"
  }
}


resource "azurerm_private_endpoint" "redis" {
  name                = "${var.project}-${var.environment}-redis-pe"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.project}-${var.environment}-redis-psc"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }
}


resource "azurerm_private_dns_a_record" "redis" {
  name                = local.redis_name
  zone_name           = "privatelink.redis.cache.windows.net"
  resource_group_name = local.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.redis.private_service_connection[0].private_ip_address]
}


resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "${var.project}-${var.environment}-redis-diag"
  target_resource_id         = azurerm_redis_cache.main.id
  log_analytics_workspace_id = var.workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}
