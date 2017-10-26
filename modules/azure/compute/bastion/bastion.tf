
resource "azurerm_storage_account" "sto-vm0" {
  name                     = "${var.storage_account_name}"  #It would be better to have a unique identifier
  location                 = "${var.location}"
  resource_group_name      = "${var.resource_group_name}"
  account_kind             = "${var.storage_account_kind}"
  account_type             = "${var.storage_account_type}"
  account_replication_type = "LRS"
  account_tier = "Standard"
}

resource "azurerm_public_ip" "bastionpip" {
    name                         = "pipBastion"
    location                     = "${var.location}"
    resource_group_name          = "${var.resource_group_name}"
    public_ip_address_allocation = "dynamic"
}

resource "azurerm_network_security_group" "security_group" {
  name                  = "${var.network_security_group_name}"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group_name}"
}

resource "azurerm_network_interface" "nic" {
  name                = "nicBastion"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  enable_ip_forwarding = "${var.enabled_ip_forwarding}"
  network_security_group_id = "${azurerm_network_security_group.security_group.id}"

  ip_configuration {
    name                          = "ipconfigbastion"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.bastionpip.id}"
    primary = "true"
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.vm_name_prefix}-vm"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group_name}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${azurerm_network_interface.nic.id}"]

  storage_image_reference {
    publisher = "${var.image_publisher}"
    offer     = "${var.image_offer}"
    sku       = "${var.image_sku}"
    version   = "${var.image_version}"
  }

  storage_os_disk {
    name          = "${var.vm_name_prefix}-vm-os.vhd"
    vhd_uri       = "https://${azurerm_storage_account.sto-vm0.name}.blob.core.windows.net/${azurerm_storage_account.sto-vm0.name}-vhds/${var.vm_name_prefix}-vm-os.vhd"
    create_option = "FromImage"
    caching = "ReadWrite"
  }

  storage_data_disk {
    name            = "${var.vm_name_prefix}-vm-dataDisk1.vhd"
    vhd_uri         = "https://${azurerm_storage_account.sto-vm0.name}.blob.core.windows.net/${azurerm_storage_account.sto-vm0.name}-vhds/${var.vm_name_prefix}-vm-dataDisk1.vhd"
    create_option   = "Empty"
    lun             = 0
    disk_size_gb    = "128"
  }


  os_profile {
    computer_name  = "${var.vm_computer_name}"
    admin_username = "${var.vm_admin_username}"
    admin_password = "${var.vm_admin_password}"
  }

  os_profile_windows_config {
      provision_vm_agent = true
  }
}

resource "azurerm_virtual_machine_extension" "iaas" {
  name                 = "IaaSAntimalware"
  location             = "${var.location}"
  resource_group_name  = "${var.resource_group_name}"
  virtual_machine_name = "${azurerm_virtual_machine.vm.name}"
  publisher            = "Microsoft.Azure.Security"
  type                 = "IaaSAntimalware"
  type_handler_version = "1.3"
  depends_on           = ["azurerm_virtual_machine.vm"]

  settings = <<SETTINGS
  {
            "AntimalwareEnabled": true,
            "RealtimeProtectionEnabled": "true",
            "ScheduledScanSettings": {
              "isEnabled": "false",
              "day": "7",
              "time": "120",
              "scanType": "Quick"
            },
            "Exclusions": {
              "Extensions": "",
              "Paths": "",
              "Processes": ""
            }
          }
SETTINGS
}


resource "azurerm_network_security_rule" "security_rule_rdp" {
  name                        = "rdp"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${var.resource_group_name}"
  network_security_group_name = "${azurerm_network_security_group.security_group.name}"
}

resource "azurerm_network_security_rule" "security_rule_ssh" {
  name                        = "ssh"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${var.resource_group_name}"
  network_security_group_name = "${azurerm_network_security_group.security_group.name}"
}
output "bastion_id" { value = "${azurerm_virtual_machine.vm.id}" }
