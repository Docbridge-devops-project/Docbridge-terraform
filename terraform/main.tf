# Root Main Module Orchestrating all Sub-Modules

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

# 1. Storage module (independent)
module "storage" {
  source      = "./modules/storage"
  project     = var.project
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}

# 2. Monitoring module (independent)
module "monitoring" {
  source                = "./modules/monitoring"
  project               = var.project
  environment           = var.environment
  location              = var.location
  tags                  = local.common_tags
  alert_email           = var.alert_email
  aks_cluster_id        = module.aks.cluster_id
  app_gateway_id        = module.appgateway.app_gateway_id
  postgres_server_id    = module.database.server_id
  key_vault_id          = module.keyvault.key_vault_id
  redis_id              = "" # Redis is deployed in AKS, no Azure resource ID needed
  app_gateway_public_ip = module.appgateway.public_ip_address
}

# 3. Networking module (independent after flow log removal)
module "networking" {
  source      = "./modules/networking"
  project     = var.project
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}

# 4. ACR module (depends on networking)
module "acr" {
  source      = "./modules/acr"
  project     = var.project
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}

# 5. Key Vault module (depends on networking)
module "keyvault" {
  source                    = "./modules/keyvault"
  project                   = var.project
  environment               = var.environment
  location                  = var.location
  tags                      = local.common_tags
  pe_subnet_id              = module.networking.pe_subnet_id
  dns_zone_id               = module.networking.kv_dns_zone_id
  aks_workload_identity_oid = module.aks.workload_identity_principal_id
  db_password               = var.db_password
  jwt_access_secret         = var.jwt_access_secret
  jwt_refresh_secret        = var.jwt_refresh_secret
  azure_openai_key          = var.azure_openai_key
  redis_connection_string   = "redis://redis.docbridge.svc.cluster.local:6379"
}

# 6. Redis module (removed as it's deploying inside AKS cluster)
# module "redis" {
#   source       = "./modules/redis"
#   project      = var.project
#   environment  = var.environment
#   location     = var.location
#   tags         = local.common_tags
#   pe_subnet_id = module.networking.pe_subnet_id
#   dns_zone_id  = module.networking.redis_dns_zone_id
#   workspace_id = module.monitoring.workspace_id
# }

# 7. Service Bus module (depends on networking)
module "servicebus" {
  source      = "./modules/servicebus"
  project     = var.project
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}

# 8. Database module (depends on networking)
module "database" {
  source               = "./modules/database"
  project              = var.project
  environment          = var.environment
  location             = var.location
  tags                 = local.common_tags
  db_password          = var.db_password
  database_subnet_id   = module.networking.database_subnet_id
  postgres_dns_zone_id = module.networking.postgres_dns_zone_id
  workspace_id         = module.monitoring.workspace_id
}

# 9. App Gateway module (depends on networking)
module "appgateway" {
  source          = "./modules/appgateway"
  project         = var.project
  environment     = var.environment
  location        = var.location
  tags            = local.common_tags
  appgw_subnet_id = module.networking.appgw_subnet_id
  workspace_id    = module.monitoring.workspace_id
}

# 10. AKS module (depends on networking, acr, keyvault, monitoring, appgateway)
module "aks" {
  source                     = "./modules/aks"
  project                    = var.project
  environment                = var.environment
  location                   = var.location
  tags                       = local.common_tags
  acr_id                     = module.acr.acr_id
  app_gateway_id             = module.appgateway.app_gateway_id
  key_vault_id               = module.keyvault.key_vault_id
  aks_subnet_id              = module.networking.aks_subnet_id
  appgw_subnet_id            = module.networking.appgw_subnet_id
  resource_group_name        = "${var.project}-rg"
  resource_group_id          = "/subscriptions/${var.subscription_id}/resourceGroups/${var.project}-rg"
  log_analytics_workspace_id = module.monitoring.workspace_id

  # Cluster sizing configs
  system_node_count  = var.system_node_count
  system_node_size   = var.system_node_size
  app_node_min_count = var.app_node_min_count
  app_node_max_count = var.app_node_max_count
  app_node_size      = var.app_node_size
}

# 11. Security module (depends on all others to enforce policies/locks after resources are built)
module "security" {
  source              = "./modules/security"
  project             = var.project
  environment         = var.environment
  alert_email         = var.alert_email
  resource_group_name = "${var.project}-rg"

  depends_on = [
    module.storage,
    module.monitoring,
    module.networking,
    module.acr,
    module.keyvault,
    module.servicebus,
    module.database,
    module.appgateway,
    module.aks
  ]
}
