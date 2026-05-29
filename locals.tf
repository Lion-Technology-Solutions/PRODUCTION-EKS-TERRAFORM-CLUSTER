locals {
  cluster_name = var.cluster_name

  common_tags = merge(
    {
      Project     = "liontech"
      Application = "production-eks"
      Environment = var.environment
      Cluster     = local.cluster_name
      ManagedBy   = "Terraform"
      Owner       = "LionTech DevOps Students"
    },
    var.tags
  )
}

