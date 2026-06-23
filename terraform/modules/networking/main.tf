# Networking Module: VNet, Subnets, NSGs, DNS Zones, links, Flow Logs

locals {
  resource_group_name = "${var.project}-rg"
}

# 1. Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.project}-${var.environment}-vnet"
  location            = var.location
  resource_group_name = local.resource_group_name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# 2. Subnets
resource "azurerm_subnet" "aks" {
  name                 = "${var.project}-${var.environment}-aks-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "appgw" {
  name                 = "${var.project}-${var.environment}-appgw-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "database" {
  name                 = "${var.project}-${var.environment}-db-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "postgres-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "pe" {
  name                                      = "${var.project}-${var.environment}-pe-subnet"
  resource_group_name                       = local.resource_group_name
  virtual_network_name                      = azurerm_virtual_network.main.name
  address_prefixes                          = ["10.0.4.0/24"]
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.5.0/26"]
}

resource "azurerm_subnet" "management" {
  name                 = "${var.project}-${var.environment}-mgmt-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.6.0/28"]
}

# 3. Network Security Groups (NSGs)

# NSG for App Gateway
resource "azurerm_network_security_group" "appgw" {
  name                = "${var.project}-${var.environment}-appgw-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Priority 100: Allow GatewayManager inbound
  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # Priority 110: Allow Internet inbound 443
  security_rule {
    name                       = "AllowInternet443Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Priority 120: Allow Internet inbound 80
  security_rule {
    name                       = "AllowInternet80Inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Priority 130: Allow AzureLoadBalancer inbound
  security_rule {
    name                       = "AllowLoadBalancerInbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Priority 4000: Deny all inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for AKS Subnet
resource "azurerm_network_security_group" "aks" {
  name                = "${var.project}-${var.environment}-aks-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Priority 100: Allow from AppGW subnet
  security_rule {
    name                       = "AllowAppGWToAKSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "3000", "3001", "3002", "3003", "3004", "3005", "3006", "3007", "3008", "3009"]
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # Priority 110: Allow AzureLoadBalancer inbound
  security_rule {
    name                       = "AllowLoadBalancerToAKSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Priority 120: Allow from AKS to AKS (Pod-to-Pod)
  security_rule {
    name                       = "AllowAKSToAKSInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "10.0.1.0/24"
  }

  # Priority 4000: Deny Internet inbound
  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Outbound Allow HTTPS to Internet for pulling basic ACR images
  security_rule {
    name                       = "Allow-Outbound-HTTPS"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# NSG for Database Subnet
resource "azurerm_network_security_group" "db" {
  name                = "${var.project}-${var.environment}-db-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Priority 100: Allow from AKS subnet port 5432
  security_rule {
    name                       = "AllowAKSToPostgres"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Priority 4000: Deny all inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for Private Endpoint Subnet
resource "azurerm_network_security_group" "pe" {
  name                = "${var.project}-${var.environment}-pe-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Priority 100: Allow from AKS subnet (KV:443, Redis:6380)
  security_rule {
    name                       = "AllowAKSToPEInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "6380"]
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Priority 4000: Deny all inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for Management Subnet
resource "azurerm_network_security_group" "mgmt" {
  name                = "${var.project}-${var.environment}-mgmt-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = var.tags

  # Priority 100: Allow outbound HTTP/HTTPS for updates
  security_rule {
    name                       = "AllowOutboundInternet"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Priority 4000: Deny all inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 4. NSG Associations
resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.db.id
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe.id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.mgmt.id
}

# 5. Private DNS Zones
resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project}-${var.environment}-postgres.private.postgres.database.azure.com"
  resource_group_name = local.resource_group_name
  tags                = var.tags
}

# 6. Private DNS Zone Links to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                  = "${var.project}-${var.environment}-kv-vnet-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.project}-${var.environment}-postgres-vnet-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
}


