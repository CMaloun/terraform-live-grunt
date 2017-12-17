variable "resource_group_name" {}
variable "prefix" {}
variable "location" {}
variable "storage_account_name" {}
variable "storage_account_type" {default = "Standard_GRS"}
variable "storage_account_kind" {default = "Storage"}
variable "storage_account_tier" {default     = "Standard"}
variable "storage_account_replication_type" {default     = "LRS"}
variable "enabled_ip_forwarding" {default = false}
variable "subnet_id" {}
variable "vm_computer_name" {}
variable "vm_name_prefix" {}
variable "vm_admin_password" {}
variable "vm_admin_username" {}
variable "vm_size" { default = "Standard_A2" }
variable "vm_count" {}
variable "puppet_environment" {}
variable "domain_name" {}
variable "puppetmaster_ip_address" {}
variable "puppetmaster_hostname" {}
variable "server_role" {}
variable "vm_image_id" {}

#Availability set
resource "azurerm_availability_set" "web-as" {
  name                = "web-as"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  managed = true
}

#####################################################################################################
#  Load Balancer
#####################################################################################################
resource "azurerm_public_ip" "lbpip" {
  name                         = "${var.prefix}-lbpip"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "dynamic"
}

resource "azurerm_lb" "web-lb" {
  resource_group_name = "${var.resource_group_name}"
  name                = "${var.prefix}-web-lb"
  location            = "${var.location}"

  frontend_ip_configuration {
    name                 = "web-lb-fe-config1"
    public_ip_address_id = "${azurerm_public_ip.lbpip.id}"
  }
}

resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = "${var.resource_group_name}"
  loadbalancer_id                = "${azurerm_lb.web-lb.id}"
  name                           = "lbr1"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "web-lb-fe-config1"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.backend_pool.id}"
  probe_id                       = "${azurerm_lb_probe.lb_probe.id}"
  depends_on                     = ["azurerm_lb_probe.lb_probe"]
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.web-lb.id}"
  name                = "lb-bep1"
}


resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id     = "${azurerm_lb.web-lb.id}"
  name                = "lbp1"
  protocol            = "Http"
  port                = 80
  request_path        = "/"
}

#####################################################################################################
#  Network intefaces
#####################################################################################################
resource "azurerm_network_interface" "nic" {
  name                = "nicPrimaryWEB${count.index}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  enable_ip_forwarding = "${var.enabled_ip_forwarding}"
  count = "${var.vm_count}"

  ip_configuration {
    name                          = "ipconfigNic01-web${count.index}"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.backend_pool.id}"]
    primary = "true"
  }

  ip_configuration {
    name                          = "ipconfigNic02-web${count.index}"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.backend_pool.id}"]
    primary = "false"
  }
  ip_configuration {
    name                          = "ipconfigNic03-web${count.index}"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.backend_pool.id}"]
    primary = "false"
  }

  ip_configuration {
    name                          = "ipconfigNic04-web${count.index}"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.backend_pool.id}"]
    primary = "false"
  }
}


#####################################################################################################
#  Virtual machines
#####################################################################################################

resource "azurerm_virtual_machine" "vm" {
  name                          = "${var.vm_name_prefix}-vm${count.index}"
  location                      = "${var.location}"
  resource_group_name           = "${var.resource_group_name}"
  vm_size                       = "${var.vm_size}"
  network_interface_ids         = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  availability_set_id           = "${azurerm_availability_set.web-as.id}"
  delete_os_disk_on_termination  = true
  delete_data_disks_on_termination = true
  count = "${var.vm_count}"


  storage_image_reference {
    id = "${var.vm_image_id}"
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
  }

  os_profile {
    computer_name  = "${var.vm_computer_name}${count.index}"
    admin_username = "${var.vm_admin_username}"
    admin_password = "${var.vm_admin_password}"
  }

  os_profile_windows_config {
      provision_vm_agent = true
  }
}


#####################################################################################################
#  Extensions
#####################################################################################################


  resource "azurerm_virtual_machine_extension" "install-puppet" {
   name                 = "install-puppet"
   location             = "${var.location}"
   resource_group_name  = "${var.resource_group_name}"
   virtual_machine_name = "${element(azurerm_virtual_machine.vm.*.name, count.index)}"
   publisher            = "Microsoft.Compute"
   type                 = "CustomScriptExtension"
   type_handler_version = "1.8"
   depends_on           = ["azurerm_virtual_machine.vm"]
   count = "${var.vm_count}"

    settings = <<SETTINGS
     {
         "fileUris": ["https://bitbucket.org/talentsoft/infrastructure-code/raw/master/extensions/azure/web/install_puppetagent_windows.ps1"],
         "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File install_puppetagent_windows.ps1 -PuppetEnvironment ${var.puppet_environment} -PuppetAgentCertName ${element(azurerm_virtual_machine.vm.*.name, count.index)}.${var.domain_name} -PuppetMasterIpAddress ${var.puppetmaster_ip_address} -PuppetMasterHostName ${var.puppetmaster_hostname} -PuppetAgentRole ${var.server_role}"
     }
 SETTINGS
 }




resource "azurerm_virtual_machine_extension" "join-ad-domain" {
name = "join-ad-domain"
location = "${var.location}"
resource_group_name = "${var.resource_group_name}"
virtual_machine_name = "${element(azurerm_virtual_machine.vm.*.name, count.index)}"
publisher = "Microsoft.Compute"
type = "JsonADDomainExtension"
type_handler_version = "1.3"
depends_on = ["azurerm_virtual_machine.vm"]
count = "${var.vm_count}"

  settings = <<SETTINGS
  {
    "Name": "contoso.com",
    "OUPath": "",
    "User": "contoso.com\\testuser",
    "Restart": true,
    "Options": 3
  }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "Password": "AweS0me@PW"
  }
PROTECTED_SETTINGS
}

output "ipconfig0" { value = "${azurerm_network_interface.nic.private_ip_addresses.0}" }
output "ipconfig1" { value = "${azurerm_network_interface.nic.private_ip_addresses.1}" }
output "ipconfig2" { value = "${azurerm_network_interface.nic.private_ip_addresses.2}" }
output "ipconfig3" { value = "${azurerm_network_interface.nic.private_ip_addresses.3}" }
output "modulepath" { value = "${path.module}" }
