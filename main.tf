module "vpc" {
  source = "./modules/vpc"

  cluster_name         = local.cluster_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  cluster_name = local.cluster_name
  environment  = var.environment
  tags         = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name                  = local.cluster_name
  cluster_version               = var.cluster_version
  environment                   = var.environment
  vpc_id                        = module.vpc.vpc_id
  cluster_subnet_ids            = module.vpc.private_subnet_ids
  node_subnet_ids               = var.node_subnet_type == "private" ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
  cluster_role_arn              = module.iam.eks_cluster_role_arn
  node_role_arn                 = module.iam.eks_node_role_arn
  endpoint_public_access        = var.endpoint_public_access
  endpoint_private_access       = var.endpoint_private_access
  public_access_cidrs           = var.cluster_endpoint_public_access_cidrs
  allowed_nodeport_cidrs        = var.allowed_nodeport_cidrs
  associate_public_ip_address   = var.node_subnet_type == "public"
  node_instance_types           = var.node_instance_types
  node_capacity_type            = var.node_capacity_type
  node_disk_size                = var.node_disk_size
  node_desired_size             = var.node_desired_size
  node_min_size                 = var.node_min_size
  node_max_size                 = var.node_max_size
  node_max_unavailable          = var.node_max_unavailable
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
  node_labels                   = var.node_labels
  tags                          = local.common_tags

  depends_on = [module.iam]
}

module "autoscaling" {
  source = "./modules/autoscaling"

  enabled                            = var.enable_autoscaling_addons
  cluster_name                       = module.eks.cluster_name
  cluster_oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
  aws_region                         = var.aws_region
  cluster_autoscaler_chart_version   = var.cluster_autoscaler_chart_version
  metrics_server_chart_version       = var.metrics_server_chart_version
  vertical_pod_autoscaler_enabled    = var.enable_vertical_pod_autoscaler
  vertical_pod_autoscaler_repository = var.vertical_pod_autoscaler_repository
  vertical_pod_autoscaler_chart      = var.vertical_pod_autoscaler_chart
  tags                               = local.common_tags

  depends_on = [module.eks]
}

