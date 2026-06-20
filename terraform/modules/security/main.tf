# Security Module: Azure Policies, Resource Lock, Defender for Cloud

locals {
  resource_group_name = "${var.project}-rg"
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# 1. Resource Lock: CanNotDelete on docbridge-rg
resource "azurerm_management_lock" "rg_lock" {
  name       = "${var.project}-${var.environment}-rg-lock"
  scope      = data.azurerm_resource_group.main.id
  lock_level = "CanNotDelete"
  notes      = "This resource group is locked to prevent accidental deletion."

  depends_on = [
    azurerm_resource_group_policy_assignment.require_tags,
    azurerm_resource_group_policy_assignment.deny_public_postgres,
    azurerm_resource_group_policy_assignment.https_only
  ]
}

# 2. Azure Policy Assignment: Require Tags (Built-in)
resource "azurerm_resource_group_policy_assignment" "require_tags" {
  name                 = "require-tags-policy"
  resource_group_id    = data.azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  display_name         = "Require tag on resources"
  description          = "Ensures that all resources within this resource group have the specified tag."

  parameters = jsonencode({
    tagName = {
      value = "Environment"
    }
  })
}

# 3. Azure Policy Assignment: Deny public access on PostgreSQL (Built-in)
resource "azurerm_resource_group_policy_assignment" "deny_public_postgres" {
  name                 = "deny-public-pg"
  resource_group_id    = data.azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/5e1de0e3-42cb-4ebc-a86d-61d0c619ca48"
  display_name         = "PostgreSQL flexible servers should disable public network access"
  description          = "Ensures public network access is disabled for PostgreSQL servers in the resource group."
}

# 4. Azure Policy Assignment: Enforce HTTPS only for App Services (Built-in)
resource "azurerm_resource_group_policy_assignment" "https_only" {
  name                 = "enforce-https"
  resource_group_id    = data.azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/a4af4a39-4135-47fb-b175-47fbdf85311d"
  display_name         = "Web Application should only be accessible over HTTPS"
  description          = "Enforces HTTPS connections for applications to protect data in transit."
}

# 5. Defender for Cloud: Security Contact Configuration
resource "azurerm_security_center_contact" "main" {
  email               = var.alert_email
  alert_notifications = true
  alerts_to_admins    = true
}

# 6. Defender for Cloud pricing settings (Free Tier for container registries and Kubernetes clusters)
resource "azurerm_security_center_subscription_pricing" "k8s" {
  tier          = "Free"
  resource_type = "KubernetesService"
}

resource "azurerm_security_center_subscription_pricing" "acr" {
  tier          = "Free"
  resource_type = "ContainerRegistry"
}
