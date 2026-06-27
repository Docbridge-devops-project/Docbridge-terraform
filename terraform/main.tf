

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}


module "storage" {
  source      = "./modules/storage"
  project     = var.project
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}


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
  redis_id              = ""
  app_gateway_public_ip = module.appgateway.public_ip_address
}


module "networking" {
  source      = "./modules/networking"
  project     = var.project
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}


module "acr" {
  source      = "./modules/acr"
  project     = var.project
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}


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














module "servicebus" {
  source      = "./modules/servicebus"
  project     = var.project
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}


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


module "appgateway" {
  source          = "./modules/appgateway"
  project         = var.project
  environment     = var.environment
  location        = var.location
  tags            = local.common_tags
  appgw_subnet_id = module.networking.appgw_subnet_id
  workspace_id    = module.monitoring.workspace_id
}


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


  system_node_count  = var.system_node_count
  system_node_size   = var.system_node_size
  app_node_min_count = var.app_node_min_count
  app_node_max_count = var.app_node_max_count
  app_node_size      = var.app_node_size
}


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
