variable "client_id" {}
variable "client_secret" {}
variable "subscription_id" {}
variable "tenant_id" {}
variable "resource_group_name" {}
variable "location" {}
variable "vm_computer_name" {}
variable "vm_name_prefix" {}
variable "vm_admin_password" {}
variable "vm_admin_username" {}
variable "storage_account_name" {}
variable "prefix" {}
variable "subnet_prefix" {}
variable "ad_primary_static_ip" {}
variable "ad_secondary_static_ip" {}
variable "vm_os_disk_on_termination" {}
variable "vm_data_disks_on_termination" {}
variable "tags" { type = "map"}
variable "aads_parameters_uri" {}
variable "aads_template_uri" {}


provider "azurerm" {
    client_id = "${var.client_id}" #"ff2151a0-198f-4716-a58b-f17a8d103292"
    client_secret = "${var.client_secret}"#"817d8ab7-8cf9-4193-8533-29c0b510fa1e"
    subscription_id = "${var.subscription_id}"#"c92d99d5-bf52-4de7-867f-a269bbc19b3d"
    tenant_id ="${var.tenant_id}"  #"461a774b-c94c-4ea0-b027-311a135d9234"
}

terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "azurerm" {

  }
}

data "terraform_remote_state" "network" {
  backend = "azure"
  config {
    storage_account_name = "terraformstoragesandbox"
    container_name       = "terraform"
    key                  = "network/terraform.tfstate"
    access_key = "hlktSi5s6rjmTnX6lZCfaE6fVHj7Hd8+gF0XDQv+ZIOgMwjkssBgrtzndNNtxELkKjwph/XZMF1poDYRCzDyiQ=="
    resource_group_name  = "terraformstorage"
  }
}

data "terraform_remote_state" "images" {
  backend = "azure"
  config {
    storage_account_name = "terraformstoragesandbox"
    container_name       = "terraform"
    key                  = "images/terraform.tfstate"
    access_key = "hlktSi5s6rjmTnX6lZCfaE6fVHj7Hd8+gF0XDQv+ZIOgMwjkssBgrtzndNNtxELkKjwph/XZMF1poDYRCzDyiQ=="
    resource_group_name  = "terraformstorage"
  }
}

module "security_ad" {
  source = "../../../../modules/azure/network/security/ad"
  resource_group_name = "${var.resource_group_name}"
  location = "${var.location}"
  network_security_group_name = "ad-nsg"
  virtual_network_name = "${data.terraform_remote_state.network.vnet_name}"
  subnet_prefix = "${var.subnet_prefix}"
}

module "ad_azure" {
  source                = "../../../../modules/azure/compute/ad"
  resource_group_name   = "${var.resource_group_name}"
  location = "${var.location}"
  prefix = "${var.prefix}"
  vm_computer_name = "${var.vm_computer_name}"
  vm_name_prefix = "${var.vm_name_prefix}"
  vm_admin_password =  "${var.vm_admin_password}"
  vm_admin_username = "${var.vm_admin_username}"
  vm_image_id = "${data.terraform_remote_state.images.image_web_id}"
  subnet_id = "${module.security_ad.subnet_id}"
  ad_primary_static_ip = "${var.ad_primary_static_ip}"
  ad_secondary_static_ip = "${var.ad_secondary_static_ip}"
  vm_os_disk_on_termination = "${var.vm_os_disk_on_termination}"
  vm_data_disks_on_termination = "${var.vm_data_disks_on_termination}"
  aads_parameters_uri   = "${var.aads_parameters_uri}"
  aads_template_uri   = "${var.aads_template_uri}"
}
