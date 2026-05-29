output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Worker node security group ID with NodePort access enabled."
  value       = module.eks.node_security_group_id
}

output "node_group_name" {
  description = "Managed node group name."
  value       = module.eks.node_group_name
}

output "vpc_id" {
  description = "VPC ID created for the EKS cluster."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role used by the Cluster Autoscaler Kubernetes service account."
  value       = module.autoscaling.cluster_autoscaler_role_arn
}

output "kubectl_update_kubeconfig_command" {
  description = "Command to configure kubectl for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

