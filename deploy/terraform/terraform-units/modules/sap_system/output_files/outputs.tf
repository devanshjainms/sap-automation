# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# output "output_json" {
#   value = local_file.output_json
# }

# output "ansible_inventory" {
#   value = local_file.ansible_inventory
# }

# output "ansible_inventory_yml" {
#   value = local_file.ansible_inventory_yml
# }

output "inventory_content" {
  description = "Content of the ansible inventory file"
  value       = local_file.ansible_inventory_new_yml.content
}

output "sap_parameters_content" {
  description = "Content of the sap-parameters file"
  value       = local_file.sap-parameters_yml.content
}
