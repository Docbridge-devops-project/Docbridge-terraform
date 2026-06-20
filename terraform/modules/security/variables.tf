variable "project" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment"
  type        = string
}

variable "alert_email" {
  description = "The email address for security alert contacts"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the target resource group"
  type        = string
}
