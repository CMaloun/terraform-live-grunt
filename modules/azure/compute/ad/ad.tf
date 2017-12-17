variable "resource_group_name" {}
variable "prefix" {}
variable "location" {}
variable "storage_account_type" {default = "Standard_GRS"}
variable "storage_account_kind" {default = "Storage"}
variable "storage_account_tier" {default     = "Standard"}
variable "storage_account_replication_type" {default     = "LRS"}
variable "enabled_ip_forwarding" {default = false}
variable "vm_computer_name" {}
variable "vm_name_prefix" {}
variable "vm_admin_password" {}
variable "vm_admin_username" {}
variable "vm_size" { default = "Standard_DS1_v2" }
variable "ad_primary_static_ip" {}
variable "ad_secondary_static_ip" {}
variable "vm_os_disk_on_termination" {}
variable "vm_data_disks_on_termination" {}
variable "vm_image_id"{}
variable "subnet_id" {}
variable "aads_template_uri" {}
variable "aads_parameters_uri" {}


#Availability set
resource "azurerm_availability_set" "ad-as" {
  name                = "ad-as"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  managed = true
}


#####################################################################################################
#  Network intefaces
#####################################################################################################
resource "azurerm_network_interface" "nicprimary" {
  name                = "nicadprimary"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  enable_ip_forwarding = "${var.enabled_ip_forwarding}"

  ip_configuration {
    name                          = "ipconfigadprimary"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "static"
    private_ip_address = "${var.ad_primary_static_ip}"
    primary = "true"
  }
}

resource "azurerm_network_interface" "nicsecondary" {
  name                = "nicadsecondary"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  enable_ip_forwarding = "${var.enabled_ip_forwarding}"

  ip_configuration {
    name                          = "ipconfigadsecondary"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "static"
    private_ip_address = "${var.ad_secondary_static_ip}"
    primary = "true"
  }
}


#####################################################################################################
#  Virtual machines
#####################################################################################################

resource "azurerm_virtual_machine" "vmprimary" {
  name                          = "${var.vm_name_prefix}-ad-primary"
  location                      = "${var.location}"
  resource_group_name           = "${var.resource_group_name}"
  vm_size                       = "${var.vm_size}"
  network_interface_ids         = ["${azurerm_network_interface.nicprimary.id}"]
  availability_set_id           = "${azurerm_availability_set.ad-as.id}"

  delete_os_disk_on_termination  = "${var.vm_os_disk_on_termination}"
  delete_data_disks_on_termination = "${var.vm_data_disks_on_termination}"

  storage_image_reference {
    id = "${var.vm_image_id}"
  }

  storage_os_disk {
    name          = "${var.vm_name_prefix}-vm-primary-os.vhd"
    os_type       = "windows"
    create_option = "FromImage"
    caching = "ReadWrite"
 }

  storage_data_disk {
    name            = "${var.vm_name_prefix}-vm-primary-dataDisk1.vhd"
    create_option   = "Empty"
    lun             = 0
    disk_size_gb    = "128"
  }

  os_profile {
    computer_name  = "${var.vm_computer_name}primary"
    admin_username = "${var.vm_admin_username}"
    admin_password = "${var.vm_admin_password}"
  }

  os_profile_windows_config {
      provision_vm_agent = true
  }
}

resource "azurerm_virtual_machine" "vmsecondary" {
  name                          = "${var.vm_name_prefix}-ad-secondary"
  location                      = "${var.location}"
  resource_group_name           = "${var.resource_group_name}"
  vm_size                       = "${var.vm_size}"
  network_interface_ids         = ["${azurerm_network_interface.nicsecondary.id}"]
  availability_set_id           = "${azurerm_availability_set.ad-as.id}"

  delete_os_disk_on_termination  = "${var.vm_os_disk_on_termination}"
  delete_data_disks_on_termination = "${var.vm_data_disks_on_termination}"

  storage_image_reference {
    id = "${var.vm_image_id}"
  }

  storage_os_disk {
    name          = "${var.vm_name_prefix}-vm-secondary-os.vhd"
    os_type       = "windows"
    create_option = "FromImage"
    caching = "ReadWrite"
 }

  storage_data_disk {
    name            = "${var.vm_name_prefix}-vm-secondary-dataDisk1.vhd"
    create_option   = "Empty"
    lun             = 0
    disk_size_gb    = "128"
  }

  os_profile {
    computer_name  = "${var.vm_computer_name}secondary"
    admin_username = "${var.vm_admin_username}"
    admin_password = "${var.vm_admin_password}"
  }

  os_profile_windows_config {
      provision_vm_agent = true
  }
}


resource "azurerm_template_deployment" "update_dns" {
  name                = "update_dns"
  resource_group_name = "${var.resource_group_name}"
  depends_on = ["azurerm_virtual_machine.vmsecondary","azurerm_virtual_machine.vmprimary"]
  template_body = <<DEPLOY
  {
    "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "templateRootUri": {
        "type": "string",
        "defaultValue": "${var.aads_template_uri}",
        "metadata": {
          "description": "Root path for templates"
        }
      },
      "parameterRootUri": {
        "type": "string",
        "defaultValue": "${var.aads_parameters_uri}",
        "metadata": {
          "decription": "Root path for parameters"
        }
      }
    },
    "variables": {
      "templates": {
        "deployment": {
          "virtualNetwork": "[concat(parameters('templateRootUri'), 'templates/buildingBlocks/vnet-n-subnet/azuredeploy.json')]",
          "extensions": "[concat(parameters('templateRootUri'), 'templates/buildingBlocks/virtualMachine-extensions/azuredeploy.json')]"
        },
        "parameter": {
          "vnetDnsUpdate": "[concat(parameters('parameterRootUri'), 'virtualNetwork-adds-dns.parameters.json')]",
          "adPrimaryExtension": "[concat(parameters('parameterRootUri'), 'create-adds-forest-extension.parameters.json')]",
          "adSecondaryExtension": "[concat(parameters('parameterRootUri'), 'add-adds-domain-controller.parameters.json')]"
        }
      }
    },
    "resources": [
      {
        "type": "Microsoft.Resources/deployments",
        "apiVersion": "2015-01-01",
        "name": "update-dns",
        "properties": {
          "mode": "Incremental",
          "templateLink": {
            "uri": "[variables('templates').deployment.virtualNetwork]"
          },
          "parametersLink": {
            "uri": "[variables('templates').parameter.vnetDnsUpdate]",
            "contentVersion": "1.0.0.0"
          }
        }
      },
   {
     "type": "Microsoft.Resources/deployments",
     "apiVersion": "2015-01-01",
     "name": "primary-ad-ext",
     "dependsOn": [
       "update-dns"
     ],
     "properties": {
       "mode": "Incremental",
       "templateLink": {
         "uri": "[variables('templates').deployment.extensions]"
       },
       "parametersLink": {
         "uri": "[variables('templates').parameter.adPrimaryExtension]",
         "contentVersion": "1.0.0.0"
       }
     }
   },
   {
     "type": "Microsoft.Resources/deployments",
     "apiVersion": "2015-01-01",
     "name": "secondary-ad-ext",
     "dependsOn": [
       "primary-ad-ext"
     ],
     "properties": {
       "mode": "Incremental",
       "templateLink": {
         "uri": "[variables('templates').deployment.extensions]"
       },
       "parametersLink": {
         "uri": "[variables('templates').parameter.adSecondaryExtension]",
         "contentVersion": "1.0.0.0"
       }
     }
   }

    ]
  }
DEPLOY

  deployment_mode = "Incremental"
}

output "modulepath" { value = "${path.module}" }
output "vm_primary_name" { value = "${azurerm_virtual_machine.vmprimary.name}" }
output "vm_secondary_name" { value = "${azurerm_virtual_machine.vmsecondary.name}" }
