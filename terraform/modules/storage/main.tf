# Storage Module: LRS Storage, ZRS Storage, containers, and Lifecycle Policy

locals {
  resource_group_name = "${var.project}-rg"
}

# Generate random suffix for globally unique storage account names
resource "random_id" "storage_suffix" {
  byte_length = 4
}

# 1. Storage Account 1: Standard_LRS
resource "azurerm_storage_account" "tfstate" {
  name                          = "dbstate${lower(random_id.storage_suffix.hex)}"
  resource_group_name           = local.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = true # Allowed for remote state execution by deployer

  tags = var.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

# 2. Storage Account 2: Standard_ZRS (App + Flow Logs)
resource "azurerm_storage_account" "app" {
  name                          = "dbapp${lower(random_id.storage_suffix.hex)}"
  resource_group_name           = local.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "ZRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = true # Needed for NSG flow logs collector network-wide

  tags = var.tags
}

resource "azurerm_storage_container" "nsg_flow_logs" {
  name                  = "nsg-flow-logs"
  storage_account_name  = azurerm_storage_account.app.name
  container_access_type = "private"
}

# 3. Lifecycle Policy for Flow Logs (Delete after 30 days)
resource "azurerm_storage_management_policy" "nsg_cleanup" {
  storage_account_id = azurerm_storage_account.app.id

  rule {
    name    = "CleanOldFlowLogs"
    enabled = true
    filters {
      prefix_match = ["nsg-flow-logs/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}
