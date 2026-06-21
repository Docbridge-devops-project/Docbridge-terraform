# AKS Module: Managed Identities, AKS Cluster, Node Pools, Federated Credentials, and Role Assignments

locals {
  aks_identity_name      = "${var.project}-${var.environment}-aks-identity"
  workload_identity_name = "${var.project}-${var.environment}-workload-identity"
  cluster_name           = "${var.project}-${var.environment}-aks"
}

# 1. User-Assigned Managed Identity for AKS Control Plane
resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = local.aks_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# 2. User-Assigned Managed Identity for AKS Workloads (Pods)
resource "azurerm_user_assigned_identity" "workload" {
  name                = local.workload_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# 3. AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project}-${var.environment}"
  kubernetes_version  = "1.33"
  tags                = var.tags

  depends_on = [
    azurerm_role_assignment.control_plane_network
  ]

  # Workload identity & OIDC config (Refinement 3)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_control_plane.id]
  }

  default_node_pool {
    name                         = "system"
    node_count                   = var.system_node_count
    vm_size                      = var.system_node_size
    vnet_subnet_id               = var.aks_subnet_id
    zones                        = ["1", "2"]
    only_critical_addons_enabled = true
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 30 # Size configured below D2s_v3 ephemeral limit to succeed
    temporary_name_for_rotation  = "tempnodepool"
    enable_auto_scaling          = true
    min_count                    = 1
    max_count                    = 3
    node_labels = {
      "nodepool-type" = "system"
    }
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  ingress_application_gateway {
    gateway_id = var.app_gateway_id
  }

  azure_policy_enabled = true

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# 4. User Node Pool for application workloads (with auto-scaling)
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.app_node_size
  node_count            = var.app_node_min_count
  enable_auto_scaling   = true
  min_count             = var.app_node_min_count
  max_count             = var.app_node_max_count
  vnet_subnet_id        = var.aks_subnet_id
  zones                 = ["1", "2"]
  os_disk_type          = "Ephemeral"
  os_disk_size_gb       = 30

  node_labels = {
    "nodepool-type" = "application"
  }

  tags = var.tags
}

# 5. Federated Identity Credential linking workload identity (Refinement 3)
resource "azurerm_federated_identity_credential" "workload" {
  name                = "${var.project}-${var.environment}-workload-fic"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload.id
  subject             = "system:serviceaccount:production:docbridge-workload-sa"
}

# 6. Role Assignments (Refinement 3 / Correction 8)

# Role Assignment 1: AKS kubelet identity -> AcrPull on ACR
resource "azurerm_role_assignment" "kubelet_acr" {
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = var.acr_id
}

# Role Assignment 2: Control plane identity -> Network Contributor on AKS subnet
resource "azurerm_role_assignment" "control_plane_network" {
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
  role_definition_name = "Network Contributor"
  scope                = var.aks_subnet_id
}

# Data source to fetch the actual AGIC identity and resolve the object ID (principal_id) properly.
# This works around a known issue in the azurerm provider where the cluster's ingress_application_gateway_identity
# object_id field erroneously returns the client_id instead of the object_id.
data "azurerm_user_assigned_identity" "agic" {
  name                = split("/", azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].user_assigned_identity_id)[8]
  resource_group_name = split("/", azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].user_assigned_identity_id)[4]
}

# Role Assignment 3: AGIC identity -> Contributor on App Gateway
resource "azurerm_role_assignment" "agic_appgateway" {
  principal_id         = data.azurerm_user_assigned_identity.agic.principal_id
  role_definition_name = "Contributor"
  scope                = var.app_gateway_id
}

# Role Assignment 4: AGIC identity -> Reader on resource group
resource "azurerm_role_assignment" "agic_rg" {
  principal_id         = data.azurerm_user_assigned_identity.agic.principal_id
  role_definition_name = "Reader"
  scope                = var.resource_group_id
}

# Role Assignment 5: Workload Managed Identity -> Key Vault Secrets User
resource "azurerm_role_assignment" "workload_kv" {
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = var.key_vault_id
}

# Role Assignment 6: AGIC identity -> Network Contributor on App Gateway subnet
resource "azurerm_role_assignment" "agic_subnet_network" {
  principal_id         = data.azurerm_user_assigned_identity.agic.principal_id
  role_definition_name = "Network Contributor"
  scope                = var.appgw_subnet_id
}

