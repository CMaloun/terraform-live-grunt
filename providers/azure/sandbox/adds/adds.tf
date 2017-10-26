variable "client_id" {}
variable "client_secret" {}
variable "subscription_id" {}
variable "tenant_id" {}
variable "resource_group_name" {}
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
  backend "azurerm" {}
}

module "adds_azure" {
  source                = "../../../../modules/azure/compute/adds"
  resource_group_name   = "${var.resource_group_name}"
  aads_parameters_uri   = "${var.aads_parameters_uri}"
  aads_template_uri   = "${var.aads_template_uri}"
}
