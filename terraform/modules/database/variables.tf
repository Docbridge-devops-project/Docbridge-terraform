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

variable "db_password" {
  description = "The database administrator password"
  type        = string
  sensitive   = true
}

variable "database_subnet_id" {
  description = "Resource ID of the subnet delegated to PostgreSQL"
  type        = string
}

variable "postgres_dns_zone_id" {
  description = "Resource ID of the PostgreSQL Private DNS Zone"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
}
