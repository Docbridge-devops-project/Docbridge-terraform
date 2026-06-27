

locals {
  resource_group_name = "${var.project}-rg"
  pip_name            = "${var.project}-${var.environment}-pip"
  appgw_name          = "${var.project}-${var.environment}-appgw"
  waf_policy_name     = "${var.project}-${var.environment}-wafpolicy-c"

  
  gateway_ip_configuration_name  = "${local.appgw_name}-ipconf"
  frontend_port_http_name        = "${local.appgw_name}-feport-http"
  frontend_port_https_name       = "${local.appgw_name}-feport-https"
  frontend_ip_configuration_name = "${local.appgw_name}-feip"

  frontend_pool_name    = "frontend-pool"
  api_gateway_pool_name = "api-gateway-pool"

  frontend_http_settings_name    = "frontend-http-settings"
  api_gateway_http_settings_name = "api-gateway-http-settings"

  frontend_listener_name = "frontend-listener"
  frontend_probe_name    = "frontend-probe"
  api_gateway_probe_name = "api-gateway-probe"

  url_path_map_name = "routing-path-map"
  routing_rule_name = "routing-rule"
}


resource "azurerm_public_ip" "main" {
  name                = local.pip_name
  location            = var.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}


resource "azurerm_web_application_firewall_policy" "main" {
  name                = local.waf_policy_name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    max_request_body_size_in_kb = 128
    file_upload_limit_in_mb     = 100
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}


resource "azurerm_application_gateway" "main" {
  name                = local.appgw_name
  resource_group_name = local.resource_group_name
  location            = var.location
  zones               = ["1", "2", "3"]
  tags                = var.tags
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = var.appgw_subnet_id
  }

  frontend_port {
    name = local.frontend_port_http_name
    port = 80
  }

  frontend_port {
    name = local.frontend_port_https_name
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.main.id
  }

  
  backend_address_pool {
    name = local.frontend_pool_name
  }

  backend_address_pool {
    name = local.api_gateway_pool_name
  }

  
  backend_http_settings {
    name                                = local.frontend_http_settings_name
    cookie_based_affinity               = "Disabled"
    path                                = ""
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 30
    probe_name                          = local.frontend_probe_name
    pick_host_name_from_backend_address = true
  }

  backend_http_settings {
    name                                = local.api_gateway_http_settings_name
    cookie_based_affinity               = "Disabled"
    path                                = ""
    port                                = 3000
    protocol                            = "Http"
    request_timeout                     = 30
    probe_name                          = local.api_gateway_probe_name
    pick_host_name_from_backend_address = true
  }

  
  probe {
    name                                      = local.frontend_probe_name
    protocol                                  = "Http"
    path                                      = "/healthz"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
  }

  probe {
    name                                      = local.api_gateway_probe_name
    protocol                                  = "Http"
    path                                      = "/healthz"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
  }

  
  http_listener {
    name                           = local.frontend_listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_http_name
    protocol                       = "Http"
  }

  
  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = local.frontend_pool_name
    default_backend_http_settings_name = local.frontend_http_settings_name

    path_rule {
      name                       = "api-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = local.api_gateway_pool_name
      backend_http_settings_name = local.api_gateway_http_settings_name
    }
  }

  
  request_routing_rule {
    name               = local.routing_rule_name
    rule_type          = "PathBasedRouting"
    http_listener_name = local.frontend_listener_name
    url_path_map_name  = local.url_path_map_name
    priority           = 10
  }

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      url_path_map,
      probe,
      ssl_certificate,
      tags
    ]
  }
}


resource "azurerm_monitor_diagnostic_setting" "appgw" {
  name                       = "${var.project}-${var.environment}-appgw-diag"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = var.workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}
