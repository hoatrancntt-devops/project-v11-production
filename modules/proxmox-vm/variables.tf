variable "proxmox_node" {
  type    = string
  default = "promox02"
}

variable "vm_hostname" {
  type    = string
  default = "db-server-v11"
}

variable "vm_id" {
  type    = number
  default = 200
}

variable "template_vm_id" {
  type    = number
  default = 9000
  description = "VM ID cua Ubuntu Cloud-Init template"
}

variable "vm_ip" {
  type    = string
  default = "172.199.10.180/24"
}

variable "vm_gateway" {
  type    = string
  default = "172.199.10.1"
}

variable "ssh_public_key" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "wg_private_key_proxmox" {
  type      = string
  sensitive = true
}

variable "wg_public_key_ec2" {
  type = string
}

variable "ec2_public_ip" {
  type = string
}
