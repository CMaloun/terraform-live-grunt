variable "resource_group_name" {}
variable "location" {}
variable "network_security_group_name" {}
variable "virtual_network_name" {}
variable "subnet_prefix" {}

resource "azurerm_subnet" "subnet" {
  name                 = "ad"
  virtual_network_name = "${var.virtual_network_name}"
  resource_group_name  = "${var.resource_group_name}"
  address_prefix       = "${var.subnet_prefix}"
}

output "subnet_id" { value = "${azurerm_subnet.subnet.id}" }
