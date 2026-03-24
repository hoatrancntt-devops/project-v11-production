output "vm_ip_address" {
  value = var.vm_ip
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.db_server.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.db_server.name
}
