output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "database_subnet_id" {
  value = azurerm_subnet.database.id
}

output "pe_subnet_id" {
  value = azurerm_subnet.pe.id
}

output "kv_dns_zone_id" {
  value = azurerm_private_dns_zone.kv.id
}



output "postgres_dns_zone_id" {
  value = azurerm_private_dns_zone.postgres.id
}
