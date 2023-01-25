terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.21.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

provider "null" {
  # Configuration options
}

# VARS
#============================

variable "resource_group_name" {}

variable "location" {}

variable "subnet_id" {}

variable "numbercount" {
    type 	  = number
    default       = 3
} 

# WEB SERVER FQDN
#============================

resource "random_id" "webserver_dns" {
  byte_length = 8
}

# WEB SERVER PIP
#============================

resource "azurerm_public_ip" "azuredev-web-vm-pip" {
  count 		  = var.numbercount
  name                = "manz-web-ip-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  domain_name_label   = "ca-labs-web-${count.index}-${lower(random_id.webserver_dns.hex)}"
}

# WEB SERVER NIC
#============================

resource "azurerm_network_interface" "azuredev-vm-nic" {
  count               = var.numbercount
  name                = "manz-vm-nic-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ip"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.azuredev-web-vm-pip.*.id, count.index)
  }
}

# WEB SERVER CLOUDINIT TEMPLATE EXAMPLE
#============================

data "template_cloudinit_config" "vm_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #! /bin/bash
    echo v1.00!
    echo example script only...
    EOF
  }
}

# WEBSERVER LINUX VM
#============================

resource "azurerm_linux_virtual_machine" "manz_web_vm" {
  name                  = "manz-web-vm-${count.index}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [element(azurerm_network_interface.azuredev-vm-nic.*.id, count.index)]
  size                  = "Standard_B1s"
  count 		  = var.numbercount
  computer_name                   = "manz-vm-${count.index}"
  admin_username                  = "superadmin"
  admin_password                  = "s3cr3tP@55word"
  disable_password_authentication = false

  os_disk {
    name                 = "manz-storage-vm-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  custom_data = data.template_cloudinit_config.vm_config.rendered

  tags = {
    org = "manz"
    app = "devops"
  }
}


# OUTPUTS
#============================

output "vm_public_ip" {
  value = {
    for k, v in azurerm_public_ip.azuredev-web-vm-pip : k => v.ip_address
  }
}

output "vm_dns" {
  value = {
    for k, v in azurerm_public_ip.azuredev-web-vm-pip : k => v.fqdn
  }
}