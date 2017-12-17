
terragrunt = {
  
  terraform {
    source = "../../../../modules/azure/infrastructure/network"
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
prefix = "ts"
network_address_space = "10.0.0.0/16"
network_dns_servers = [
      "10.0.4.4",
      "10.0.4.5",
      "168.63.129.16"
    ]
network_subnet_prefix = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24",
    "10.0.0.128/25"
]
network_subnet_names = [
    "web",
    "biz",
    "sql",
    "ad",
    "mgmt"]
tags  = { environment = "sanbox"}
