output "app_gateway_id" {
  value = azurerm_application_gateway.main.id
}

output "app_gateway_name" {
  value = azurerm_application_gateway.main.name
}

output "public_ip_address" {
  value = azurerm_public_ip.main.ip_address
}

output "public_ip_id" {
  value = azurerm_public_ip.main.id
}
