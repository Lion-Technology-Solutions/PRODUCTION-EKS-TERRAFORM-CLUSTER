output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Worker node security group ID."
  value       = aws_security_group.nodes.id
}

output "node_group_name" {
  description = "Managed node group name."
  value       = aws_eks_node_group.workers.node_group_name
}

output "node_group_names" {
  description = "Managed node group names."
  value       = [aws_eks_node_group.workers.node_group_name]
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

