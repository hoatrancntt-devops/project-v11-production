output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}

output "ec2_instance_id" {
  value = aws_instance.web.id
}
