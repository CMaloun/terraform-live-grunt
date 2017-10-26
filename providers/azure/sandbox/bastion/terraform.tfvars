terragrunt = {
  dependencies {
    paths = ["../network"]
  }

  # Include all settings from the root terraform.tfvars file
  include = {
    path = "${find_in_parent_folders()}"
  }
}

client_id = "ff2151a0-198f-4716-a58b-f17a8d103292"
client_secret = "817d8ab7-8cf9-4193-8533-29c0b510fa1e"
subscription_id = "c92d99d5-bf52-4de7-867f-a269bbc19b3d"
tenant_id = "461a774b-c94c-4ea0-b027-311a135d9234"
resource_group_name = "sandbox-test"
location = "West US"
storage_account_name = "bastionstoragewestus"
prefix = "ts"
vm_computer_name = "bastion"
vm_name_prefix = "sandbox-bastion"
vm_admin_password = "AweS0me@PW"
vm_admin_username = "testuser"
