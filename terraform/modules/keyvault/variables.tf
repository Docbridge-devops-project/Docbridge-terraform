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

variable "pe_subnet_id" {
  description = "Resource ID of the Private Endpoint subnet"
  type        = string
}

variable "dns_zone_id" {
  description = "Resource ID of the Key Vault Private DNS zone"
  type        = string
}

variable "aks_workload_identity_oid" {
  description = "The Object ID of the AKS Workload User Assigned Identity"
  type        = string
}

# Secrets variables
variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_access_secret" {
  type      = string
  sensitive = true
}

variable "jwt_refresh_secret" {
  type      = string
  sensitive = true
}

variable "azure_openai_key" {
  type      = string
  sensitive = true
}

variable "redis_connection_string" {
  type      = string
  sensitive = true
}
