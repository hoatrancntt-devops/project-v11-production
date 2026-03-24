output "web_app_url" {
  description = "URL truy cap Web App qua ALB"
  value       = "http://${module.aws_infra.alb_dns_name}"
}

output "ec2_public_ip" {
  description = "Public IP cua EC2"
  value       = module.aws_infra.ec2_public_ip
}

output "proxmox_vm_ip" {
  description = "IP cua VM Proxmox"
  value       = module.proxmox_vm.vm_ip_address
}

output "wireguard_tunnel" {
  description = "WireGuard VPN Tunnel"
  value       = "EC2 (10.0.0.1) <---VPN---> Proxmox (10.0.0.2)"
}
