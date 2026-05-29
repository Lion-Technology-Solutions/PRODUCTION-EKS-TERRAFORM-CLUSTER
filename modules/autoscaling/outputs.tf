output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by Cluster Autoscaler."
  value       = try(aws_iam_role.cluster_autoscaler[0].arn, null)
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA."
  value       = try(aws_iam_openid_connect_provider.this[0].arn, null)
}

