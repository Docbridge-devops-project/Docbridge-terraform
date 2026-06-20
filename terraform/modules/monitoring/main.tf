# Monitoring Module: Log Analytics Workspace, App Insights, Diagnostics, Alerts, Action Group, Web Test, Workbook, Service Health

locals {
  resource_group_name = "${var.project}-rg"
}

# 1. Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project}-${var.environment}-law-c"
  location            = var.location
  resource_group_name = local.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags                = var.tags
}

# 2. Application Insights
resource "azurerm_application_insights" "main" {
  name                 = "${var.project}-${var.environment}-appinsights"
  location             = var.location
  resource_group_name  = local.resource_group_name
  workspace_id         = azurerm_log_analytics_workspace.main.id
  application_type     = "web"
  sampling_percentage  = 50
  daily_data_cap_in_gb = 0.5
  tags                 = var.tags
}

# 3. Diagnostic Settings (routed to LAW)

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.project}-${var.environment}-aks-diag"
  target_resource_id         = var.aks_cluster_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "kube-apiserver"
  }
  enabled_log {
    category = "kube-controller-manager"
  }
  enabled_log {
    category = "cluster-autoscaler"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "${var.project}-${var.environment}-kv-diag"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# 4. Action Group for Alerts
resource "azurerm_monitor_action_group" "email" {
  name                = "${var.project}-${var.environment}-actiongroup"
  resource_group_name = local.resource_group_name
  short_name          = "db-alert"
  tags                = var.tags

  email_receiver {
    name                    = "admin-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# 5. Alert Rules

# Alert Rule 1: AKS Memory > 85% for 15 minutes
resource "azurerm_monitor_metric_alert" "aks_memory" {
  name                = "aks-memory-alert"
  resource_group_name = local.resource_group_name
  scopes              = [var.aks_cluster_id]
  description         = "Triggers when node memory utilization exceeds 85% for 15 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}

# Alert Rule 2: Pod Restarts > 5 in 15 minutes
resource "azurerm_monitor_scheduled_query_rules_alert" "pod_restarts" {
  name                = "pod-restarts-alert"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags
  depends_on          = [azurerm_role_assignment.monitoring_contributor]

  action {
    action_group = [azurerm_monitor_action_group.email.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert when pod restarts > 5 in a 15-minute window"
  enabled        = true
  query          = <<-QUERY
    KubePodInventory
    | where TimeGenerated > ago(15m)
    | summarize Restarts = max(ContainerRestartCount) - min(ContainerRestartCount) by Name, Namespace
    | where Restarts > 5
  QUERY
  severity       = 1
  frequency      = 5
  time_window    = 15
  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
}

# Alert Rule 3: PostgreSQL connections > 80%
resource "azurerm_monitor_metric_alert" "db_connections" {
  name                = "postgres-connections-alert"
  resource_group_name = local.resource_group_name
  scopes              = [var.postgres_server_id]
  description         = "Triggers when active database connections exceed 80."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "active_connections"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}

# Alert Rule 4: App error rate > 5% for 10 minutes
resource "azurerm_monitor_scheduled_query_rules_alert" "app_errors" {
  name                = "app-errors-alert"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags
  depends_on          = [azurerm_role_assignment.monitoring_contributor]

  action {
    action_group = [azurerm_monitor_action_group.email.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert when App Insights 5xx error rate > 5% for 10 minutes"
  enabled        = true
  query          = <<-QUERY
    AppRequests
    | where TimeGenerated > ago(10m)
    | summarize Total = count(), Errors = countif(ResultCode startswith "5")
    | extend ErrorRate = (todouble(Errors) / todouble(Total)) * 100.0
    | where ErrorRate > 5.0
  QUERY
  severity       = 1
  frequency      = 5
  time_window    = 10
  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
}

# Alert Rule 5: WAF Blocked requests > 50 in 5 minutes
resource "azurerm_monitor_scheduled_query_rules_alert" "waf_blocked" {
  name                = "waf-blocked-alert"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags
  depends_on          = [azurerm_role_assignment.monitoring_contributor]

  action {
    action_group = [azurerm_monitor_action_group.email.id]
  }

  data_source_id = azurerm_log_analytics_workspace.main.id
  description    = "Alert when WAF blocked requests > 50 in a 5-minute window"
  enabled        = true
  query          = <<-QUERY
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
    | where action_s == "Blocked"
    | summarize BlockCount = count()
    | where BlockCount > 50
  QUERY
  severity       = 1
  frequency      = 5
  time_window    = 5
  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
}

# 6. Availability Test (Web Ping)
resource "azurerm_application_insights_web_test" "ping_test" {
  name                    = "${var.project}-${var.environment}-ping-test"
  location                = var.location
  resource_group_name     = local.resource_group_name
  application_insights_id = azurerm_application_insights.main.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-ca-sjc-azr", "us-va-ash-azr", "emea-gb-db3-azr"]

  configuration = <<XML
<WebTest Name="ping-test" Id="00000000-0000-0000-0000-000000000000" Enabled="True" CssProject="" CssTemplate="" UseControlPlaybook="False" Urg="False" PassPriority="3" MaxRecurrences="0" Type="ping" Version="1.0" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Items>
    <Request Method="GET" Guid="00000000-0000-0000-0000-000000000000" Version="1.0" Url="http://${var.app_gateway_public_ip}/api/v1/health" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" AcceptSourceHeader="True" IgnoreHttpStatusCode="False">
      <ValidationRules>
        <ValidationRule Classname="Microsoft.VisualStudio.TestTools.WebTesting.Rules.ValidateResponseUrl, Microsoft.VisualStudio.QualityTools.WebTestFramework, Version=10.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" DisplayName="Response URL Validation" Description="Validates that the response URL is identical to the requested URL." Level="Info" ExecutionOrder="BeforeTemplate" />
      </ValidationRules>
    </Request>
  </Items>
</WebTest>
XML

  tags = var.tags
}

# 7. Azure Monitor Workbook (AKS + AppGW + Postgres Dashboard)
resource "azurerm_application_insights_workbook" "dashboard" {
  name                = "00000000-0000-0000-0000-000000000001" # UUID needed
  resource_group_name = local.resource_group_name
  location            = var.location
  display_name        = "DocBridge Unified Infrastructure Dashboard"

  data_json = jsonencode({
    "version" = "Notebook/1.0",
    "items" = [
      {
        "type" = 1,
        "content" = {
          "json" = "## DocBridge Performance and Health Dashboard\nThis dashboard tracks resource performance metrics for AKS, App Gateway, and PostgreSQL."
        },
        "name" = "intro"
      }
    ]
  })

  tags = var.tags
}

# 8. Service Health Alert for Central US
resource "azurerm_monitor_activity_log_alert" "service_health" {
  name                = "service-health-alert"
  resource_group_name = local.resource_group_name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
  description         = "Alert when there is a service health incident in Central US"
  tags                = var.tags

  criteria {
    category = "ServiceHealth"
    service_health {
      locations = ["Central US"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}

data "azurerm_client_config" "current" {}

# Role Assignment: Give the deploying service principal "Monitoring Contributor"
# on the Log Analytics Workspace so it can create scheduled query alert rules.
resource "azurerm_role_assignment" "monitoring_contributor" {
  scope                = azurerm_log_analytics_workspace.main.id
  role_definition_name = "Monitoring Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
