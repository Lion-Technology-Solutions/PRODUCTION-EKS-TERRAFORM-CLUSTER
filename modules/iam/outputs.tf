output "eks_cluster_role_arn" {
  description = "EKS control plane IAM role ARN."
  value       = aws_iam_role.eks_cluster.arn

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

output "eks_node_role_arn" {
  description = "EKS managed node group IAM role ARN."
  value       = aws_iam_role.eks_node.arn

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ssm,
    aws_iam_role_policy_attachment.node_cloudwatch,
    aws_iam_role_policy_attachment.node_ebs_csi
  ]
}

output "eks_node_role_name" {
  description = "EKS managed node group IAM role name."
  value       = aws_iam_role.eks_node.name
}
