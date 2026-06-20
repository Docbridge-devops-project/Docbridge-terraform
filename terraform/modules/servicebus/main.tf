# Service Bus Module: Namespace and Queues (Private endpoint unsupported on Basic SKU)

locals {
  resource_group_name = "${var.project}-rg"
  sb_name             = "${var.project}-${var.environment}-sbus"
}

# 1. Service Bus Namespace
resource "azurerm_servicebus_namespace" "main" {
  name                = local.sb_name
  location            = var.location
  resource_group_name = local.resource_group_name
  sku                 = "Basic"
  tags                = var.tags
}

# 2. Queues
resource "azurerm_servicebus_queue" "medicine" {
  name         = "medicine-reminders"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count                   = 3
  dead_lettering_on_message_expiration = true
}

resource "azurerm_servicebus_queue" "followup" {
  name         = "followup-reminders"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count                   = 3
  dead_lettering_on_message_expiration = true
}
