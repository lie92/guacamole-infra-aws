# IP guacamole
output "ip_guacamole" {
  description = "Ip guacamole"
  value       = module.ec2_guacamole.public_ip
}