# Management VM and Azure Bastion configuration

# 1. Public IP for Azure Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "${var.project}-${var.environment}-bastion-ip"
  location            = var.location
  resource_group_name = "${var.project}-rg"
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# 2. Azure Bastion Host
resource "azurerm_bastion_host" "main" {
  name                = "${var.project}-${var.environment}-bastion"
  location            = var.location
  resource_group_name = "${var.project}-rg"
  tags                = local.common_tags
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = module.networking.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# 3. TLS SSH Key Generator
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 4. Save VM SSH Private Key securely in Key Vault as a secret
resource "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "mgmt-vm-ssh-private-key"
  value        = tls_private_key.ssh.private_key_pem
  key_vault_id = module.keyvault.key_vault_id
}

# 5. Network Interface for Management VM (No public IP)
resource "azurerm_network_interface" "mgmt" {
  name                = "${var.project}-${var.environment}-mgmt-nic"
  location            = var.location
  resource_group_name = "${var.project}-rg"
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.networking.management_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# 6. Linux Virtual Machine (Ubuntu 22.04 LTS)
resource "azurerm_linux_virtual_machine" "mgmt" {
  name                = "${var.project}-${var.environment}-mgmt-vm"
  resource_group_name = "${var.project}-rg"
  location            = var.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  network_interface_ids = [
    azurerm_network_interface.mgmt.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# 7. Role Assignment for Management VM to access AKS cluster
resource "azurerm_role_assignment" "mgmt_aks_admin" {
  name                 = "8cd5fe68-191d-4e42-9271-b6a87dc5e12d"
  scope                = module.aks.cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = azurerm_linux_virtual_machine.mgmt.identity[0].principal_id
}

