

locals {
  resource_group_name = "${var.project}-rg"
  vault_name          = "${var.project}-${var.environment}-kv"
}

data "azurerm_client_config" "current" {}


resource "azurerm_key_vault" "main" {
  name                          = local.vault_name
  location                      = var.location
  resource_group_name           = local.resource_group_name
  enabled_for_disk_encryption   = true
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  sku_name                      = "standard"
  public_network_access_enabled = true

  network_acls {
    default_action             = "Allow"
    bypass                     = "AzureServices"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }


  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }


  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = var.aks_workload_identity_oid
    secret_permissions = [
      "Get", "List"
    ]
  }

  tags = var.tags
}


resource "azurerm_private_endpoint" "kv" {
  name                = "${var.project}-${var.environment}-kv-pe"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.project}-${var.environment}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}


resource "azurerm_private_dns_a_record" "kv" {
  name                = local.vault_name
  zone_name           = "privatelink.vaultcore.azure.net"
  resource_group_name = local.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.kv.private_service_connection[0].private_ip_address]
}


locals {
  secrets_map = {
    "db-password"             = var.db_password
    "jwt-access-secret"       = var.jwt_access_secret
    "jwt-refresh-secret"      = var.jwt_refresh_secret
    "azure-openai-key"        = var.azure_openai_key
    "redis-connection-string" = var.redis_connection_string
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each     = local.secrets_map
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.main.id


  depends_on = [
    azurerm_key_vault.main
  ]
}
