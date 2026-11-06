output "id" {
  description = "Bastion host EC2 Instance ID."
  value       = try(aws_instance.this[0].id, "")
}

output "arn" {
  description = "ARN of the bastion host EC2 instance."
  value       = try(aws_instance.this[0].arn, "")
}

output "private_ip" {
  description = "Private IP of the bastion host EC2 instance."
  value       = try(aws_instance.this[0].private_ip, "")
}

output "role" {
  description = "ARN of AWS IAM Role associated with the instance."
  value       = try(aws_iam_role.this[0].arn, "")
}

output "security_group_id" {
  description = "ID of the bastion host's security group."
  value       = try(aws_security_group.this[0].id, "")
}
