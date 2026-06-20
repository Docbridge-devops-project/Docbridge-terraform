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

variable "appgw_subnet_id" {
  description = "Resource ID of the Application Gateway subnet"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
}
