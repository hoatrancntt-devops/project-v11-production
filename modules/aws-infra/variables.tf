variable "project_name" {
  type    = string
  default = "project-v11"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ssh_public_key" {
  type = string
}

variable "team_name" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "wg_private_key_ec2" {
  type      = string
  sensitive = true
}

variable "wg_public_key_proxmox" {
  type = string
}

variable "proxmox_public_ip" {
  type = string
}
