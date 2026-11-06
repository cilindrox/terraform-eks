output "bastion_host_instance_id" {
  description = "Bastion host EC2 instance id."
  value       = aws_instance.bastion_host.id
}
