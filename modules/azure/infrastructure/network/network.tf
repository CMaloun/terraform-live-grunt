variable "resource_group_name" {}
variable "prefix" {}
variable "location" {}
variable "client_id" {}
variable "client_secret" {}
variable "subscription_id" {}
variable "tenant_id" {}
variable "network_address_space" {}
variable "network_dns_servers" { type = "list" }
variable "network_subnet_prefix" { type = "list" }
variable "network_subnet_names" { type = "list" }
variable "tags" { type = "map"}


provider "azurerm" {
    client_id = "${var.client_id}" #"ff2151a0-198f-4716-a58b-f17a8d103292"
    client_secret = "${var.client_secret}"#"817d8ab7-8cf9-4193-8533-29c0b510fa1e"
    subscription_id = "${var.subscription_id}"#"c92d99d5-bf52-4de7-867f-a269bbc19b3d"
    tenant_id ="${var.tenant_id}"  #"461a774b-c94c-4ea0-b027-311a135d9234"
}
# create a resource group
resource "azurerm_resource_group" "sandbox" {
  name = "${var.resource_group_name}"
  location = "${var.location}"
}

terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "azurerm" {}
}

module "network" {
  source = "../network/vnet"
  resource_group_name = "${azurerm_resource_group.sandbox.name}"
  location = "${var.location}"
  prefix = "${var.prefix}"
  tags = "${var.tags}"
  address_space = "${var.network_address_space}"
  dns_servers = "${var.network_dns_servers}"
  subnet_prefixes = "${var.network_subnet_prefix}"
  subnet_names = "${var.network_subnet_names}"
}

output "vnet_name" { value = "${module.network.vnet_name}" }
output "vnet_id" {value = "${module.network.vnet_id}"}
output "nsg_subnets" { value = "${module.network.nsg_subnets}" }
