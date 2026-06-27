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

variable "alert_email" {
  description = "Email receiver for alerts"
  type        = string
}


variable "aks_cluster_id" {
  type = string
}

variable "app_gateway_id" {
  type = string
}

variable "postgres_server_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "redis_id" {
  type = string
}

variable "app_gateway_public_ip" {
  type = string
}
