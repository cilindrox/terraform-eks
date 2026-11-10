output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "bastion_instance_id" {
  description = "Bastion host EC2 Instance ID."
  value       = module.bastion.id
}
