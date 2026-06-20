variable "project" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment"
  type        = string
}

variable "location" {
  description = "Azure region to deploy resources in"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "The Resource ID of the resource group"
  type        = string
}

variable "acr_id" {
  description = "The Resource ID of the Azure Container Registry"
  type        = string
}

variable "app_gateway_id" {
  description = "The Resource ID of the Application Gateway"
  type        = string
}

variable "key_vault_id" {
  description = "The Resource ID of the Key Vault"
  type        = string
}

variable "aks_subnet_id" {
  description = "The Resource ID of the AKS subnet"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace for Container Insights"
  type        = string
}

variable "system_node_count" {
  description = "Number of system nodes in AKS"
  type        = number
}

variable "system_node_size" {
  description = "VM size of system nodes"
  type        = string
}

variable "app_node_min_count" {
  description = "Min node count of autoscale app pool"
  type        = number
}

variable "app_node_max_count" {
  description = "Max node count of autoscale app pool"
  type        = number
}

variable "app_node_size" {
  description = "VM size of application nodes"
  type        = string
}

variable "appgw_subnet_id" {
  description = "The Resource ID of the App Gateway subnet"
  type        = string
}

