# ============================================
# main.tf - Root Module: Goi AWS + Proxmox
# ============================================

module "aws_infra" {
  source = "./modules/aws-infra"

  project_name          = "project-v11"
  instance_type         = var.ec2_instance_type
  ssh_public_key        = var.ssh_public_key
  team_name             = var.team_name
  db_password           = var.db_password
  wg_private_key_ec2    = var.wg_private_key_ec2
  wg_public_key_proxmox = var.wg_public_key_proxmox
  proxmox_public_ip     = var.proxmox_public_ip
}

module "proxmox_vm" {
  source = "./modules/proxmox-vm"

  proxmox_node           = var.proxmox_node
  vm_ip                  = var.vm_ip
  vm_gateway             = var.vm_gateway
  ssh_public_key         = var.ssh_public_key
  db_password            = var.db_password
  wg_private_key_proxmox = var.wg_private_key_proxmox
  wg_public_key_ec2      = var.wg_public_key_ec2
  ec2_public_ip          = module.aws_infra.ec2_public_ip
}
