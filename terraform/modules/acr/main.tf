# ACR Module: Registry only (Private endpoint unsupported on Basic SKU)

locals {
  resource_group_name = "${var.project}-rg"
  # ACR name must be alphanumeric only
  acr_name = "${var.project}${var.environment}acr"
}

# 1. Container Registry
resource "azurerm_container_registry" "main" {
  name                          = local.acr_name
  resource_group_name           = local.resource_group_name
  location                      = var.location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = var.tags
}
