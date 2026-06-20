output "workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "workspace_uuid" {
  description = "The GUID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "workspace_key" {
  value     = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive = true
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}

output "app_insights_instrumentation_key" {
  value     = azurerm_application_insights.main.instrumentation_key
  sensitive = true
}
