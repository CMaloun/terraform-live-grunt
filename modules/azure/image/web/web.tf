variable "resource_group_name" {}
variable "location" {}
variable "image_uri" {}
variable "image_name" {}

resource "azurerm_image" "image" {
    name = "${var.image_name}"
    location = "${var.location}"
    resource_group_name = "${var.resource_group_name}"

    os_disk {
      blob_uri          = "${var.image_uri}"
      os_type       = "windows"
      os_state = "Generalized"
      caching = "ReadWrite"
   }
}

output "image_id" { value = "${azurerm_image.image.id}" }
