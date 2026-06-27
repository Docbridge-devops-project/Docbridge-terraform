

locals {
  resource_group_name = "${var.project}-rg"
  sb_name             = "${var.project}-${var.environment}-sbus"
}


resource "azurerm_servicebus_namespace" "main" {
  name                = local.sb_name
  location            = var.location
  resource_group_name = local.resource_group_name
  sku                 = "Basic"
  tags                = var.tags
}


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
