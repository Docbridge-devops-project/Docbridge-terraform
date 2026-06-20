output "app_gateway_public_ip" {
  description = "The public IP address of the Application Gateway"
  value       = module.appgateway.public_ip_address
}

output "app_gateway_name" {
  description = "The name of the Application Gateway"
  value       = module.appgateway.app_gateway_name
}

output "app_gateway_id" {
  description = "The resource ID of the Application Gateway"
  value       = module.appgateway.app_gateway_id
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_resource_group" {
  description = "The resource group containing the AKS cluster"
  value       = "${var.project}-rg"
}

output "acr_login_server" {
  description = "The login server URI for the Azure Container Registry"
  value       = module.acr.acr_login_server
}

output "acr_name" {
  description = "The name of the Azure Container Registry"
  value       = module.acr.acr_name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = module.keyvault.key_vault_uri
}

output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = module.keyvault.key_vault_name
}

output "key_vault_id" {
  description = "The resource ID of the Key Vault"
  value       = module.keyvault.key_vault_id
}

output "postgres_fqdn" {
  description = "The FQDN of the PostgreSQL Flexible Server"
  value       = module.database.server_fqdn
}

output "redis_hostname" {
  description = "Internal Redis hostname (in-cluster deployment)"
  value       = "redis.docbridge.svc.cluster.local"
}

output "log_analytics_workspace_id" {
  description = "The resource ID of the Log Analytics Workspace"
  value       = module.monitoring.workspace_id
}

output "app_insights_connection_string" {
  description = "The connection string for Application Insights"
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
}

output "app_insights_instrumentation_key" {
  description = "The instrumentation key for Application Insights"
  value       = module.monitoring.app_insights_instrumentation_key
  sensitive   = true
}

output "workload_identity_client_id" {
  description = "The Client ID of the workload identity user assigned identity"
  value       = module.aks.workload_identity_client_id
}

output "service_bus_namespace_name" {
  description = "The name of the Service Bus namespace"
  value       = module.servicebus.namespace_name
}

output "estimated_monthly_cost_note" {
  description = "Estimated monthly cost breakdown"
  value = {
    aks_system_nodes = "~$70/month per Standard_D2s_v3 node"
    aks_app_nodes    = "~$70/month per Standard_D2s_v3 node"
    postgresql       = "~$13/month Burstable B2s"
    app_gateway_waf  = "~$40/month Standard_v2"
    acr_basic        = "~$5/month Basic SKU"
    key_vault        = "~$1/month Standard SKU"
    storage_accounts = "~$3/month"
    service_bus      = "~$1/month Basic SKU"
    log_analytics    = "~$0-5/month first 5GB free"
    total_estimate   = "~$200-250/month"
  }
}
