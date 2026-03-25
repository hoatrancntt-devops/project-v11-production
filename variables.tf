# ============================================
# variables.tf - Bien so duoc quan ly tren HCP
# ============================================

# === AWS Variables ===
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "team_name" {
  description = "Ten nhom hien thi tren Web App"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key inject vao EC2 va Proxmox VM"
  type        = string
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.micro"
}

# === Proxmox Variables ===
variable "proxmox_api_url" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "promox02"
}

variable "vm_ip" {
  type    = string
  default = "172.199.10.180/24"
}

variable "vm_gateway" {
  type    = string
  default = "172.199.10.1"
}

# === Database ===
variable "db_password" {
  type      = string
  sensitive = true
}

# === WireGuard ===
variable "wg_private_key_ec2" {
  type      = string
  sensitive = true
}

variable "wg_public_key_ec2" {
  type = string
}

variable "wg_private_key_proxmox" {
  type      = string
  sensitive = true
}

variable "wg_public_key_proxmox" {
  type = string
}
variable "proxmox_ssh_password" {
  type      = string
  sensitive = true
}
