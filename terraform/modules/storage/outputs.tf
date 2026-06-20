output "tfstate_storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "app_storage_account_name" {
  value = azurerm_storage_account.app.name
}

output "app_storage_account_id" {
  value = azurerm_storage_account.app.id
}

output "app_storage_primary_connection_string" {
  value     = azurerm_storage_account.app.primary_connection_string
  sensitive = true
}
