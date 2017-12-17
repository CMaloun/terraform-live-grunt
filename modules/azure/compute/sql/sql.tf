variable "resource_group_name" {}
variable "location" {}
variable "storage_account_name" {}
variable "storage_account_kind" {default = "Storage"}
variable "storage_account_tier" {default     = "Standard"}
variable "storage_account_replication_type" {default     = "LRS"}
variable "enabled_ip_forwarding" {default = false}
variable "subnet_id" {}
variable "dns_servers" {type = "list"}
variable "vm_admin_username" {default = "testuser"}
variable "vm_admin_password" {}
variable "vm_size" { default = "Standard_A2" }
variable "vm_sql_image_id" {}
variable "vm_domain_name" {}
variable "vm_count" {}


#virtual machines variables
variable "vm_name_prefix" {}
variable "vm_computer_name" {}

#Availability set
resource "azurerm_availability_set" "sql-as" {
  name                = "sql-as"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  managed = true
}

resource "azurerm_storage_account" "sto-sql-vm0" {
  name                     = "${var.storage_account_name}sqlvm0"  #It would be better to have a unique identifier
  location                 = "${var.location}"
  resource_group_name      = "${var.resource_group_name}"
  account_kind             = "${var.storage_account_kind}"
  account_replication_type = "${var.storage_account_replication_type}"
  account_tier             = "${var.storage_account_tier}"
}

resource "azurerm_network_interface" "nic" {
  name                = "nicSQL${count.index}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  enable_ip_forwarding = "${var.enabled_ip_forwarding}"
  count = "${var.vm_count}"

  ip_configuration {
    name                          = "ipconfigSQL${count.index}"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    primary =  "true"
  }

  dns_servers =  "${var.dns_servers}"
}


resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.vm_name_prefix}-vm0"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group_name}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count = "${var.vm_count}"
  availability_set_id   = "${azurerm_availability_set.sql-as.id}"

  storage_image_reference {
    id = "${var.vm_sql_image_id}"
  }

  storage_os_disk {
    name          = "${var.vm_name_prefix}-vm${count.index}-os.vhd"
    os_type       = "windows"
    create_option = "FromImage"
    caching = "ReadWrite"
  }

  storage_data_disk {
    name            = "${var.vm_name_prefix}-vm${count.index}-dataDisk1.vhd"
    create_option   = "Empty"
    lun             = 0
    disk_size_gb    = "128"
    caching = "ReadWrite"
  }

  storage_data_disk {
    name            = "${var.vm_name_prefix}-vm${count.index}-dataDisk2.vhd"
    create_option   = "Empty"
    lun             = 1
    disk_size_gb    = "128"
    caching = "None"
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

resource "azurerm_virtual_machine_extension" "join-ad-domain" {
name = "join-ad-domain"
location = "${var.location}"
resource_group_name = "${var.resource_group_name}"
virtual_machine_name = "${element(azurerm_virtual_machine.vm.*.name, count.index)}"
publisher = "Microsoft.Compute"
type = "JsonADDomainExtension"
type_handler_version = "1.3"
count = "${var.vm_count}"
depends_on = ["azurerm_virtual_machine.vm"]

  settings = <<SETTINGS
  {
    "Name": "${var.vm_domain_name}",
    "OUPath": "",
    "User": "${var.vm_domain_name}\\${var.vm_admin_username}",
    "Restart": true,
    "Options": 3
  }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "Password": "${var.vm_admin_password}"
  }
PROTECTED_SETTINGS
}
