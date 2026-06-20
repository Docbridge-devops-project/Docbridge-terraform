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
  description = "Resource ID of the Redis Private DNS zone"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
}
