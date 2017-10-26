variable "resource_group_name" {}
variable "location" {}
variable "client_id" {}
variable "client_secret" {}
variable "subscription_id" {}
variable "tenant_id" {}
variable "image_uri" {}
variable "image_name" {}

provider "azurerm" {
    client_id = "${var.client_id}"
    client_secret = "${var.client_secret}"
    subscription_id = "${var.subscription_id}"
    tenant_id ="${var.tenant_id}"
}

terraform {
  backend "azurerm" {}
}

# create a resource group
resource "azurerm_resource_group" "images" {
  name = "${var.resource_group_name}"
  location = "${var.location}"
}

module "image_web" {
  source = "../../../../modules/azure/image/web"
  resource_group_name = "${azurerm_resource_group.images.name}"
  location = "${azurerm_resource_group.images.location}"
  image_name = "${var.image_name}"
  image_uri = "${var.image_uri}"
}

output "image_web_id" { value = "${module.image_web.image_id}" }
