variable "subscription_id" {
  description = "The Azure subscription ID to deploy to"
  type        = string
}

variable "project" {
  description = "The name of the project"
  type        = string
  default     = "docbridge"
}

variable "environment" {
  description = "The name of the environment (e.g. dev)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "The Azure region to deploy to"
  type        = string
  default     = "eastus2"
}

variable "owner" {
  description = "The name of the resource owner/creator"
  type        = string
}

variable "alert_email" {
  description = "The email address to receive monitoring alerts"
  type        = string
}


variable "db_password" {
  description = "The administrator password for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "jwt_access_secret" {
  description = "The secret key for JWT access tokens"
  type        = string
  sensitive   = true
}

variable "jwt_refresh_secret" {
  description = "The secret key for JWT refresh tokens"
  type        = string
  sensitive   = true
}

variable "azure_openai_key" {
  description = "The API key for Azure OpenAI service"
  type        = string
  sensitive   = true
}


variable "system_node_count" {
  description = "Number of system nodes in AKS"
  type        = number
  default     = 2
}

variable "system_node_size" {
  description = "Size of system node VMs"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "app_node_min_count" {
  description = "Minimum number of application nodes in AKS"
  type        = number
  default     = 2
}

variable "app_node_max_count" {
  description = "Maximum number of application nodes in AKS"
  type        = number
  default     = 4
}

variable "app_node_size" {
  description = "Size of application node VMs"
  type        = string
  default     = "Standard_D2s_v3"
}
