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
