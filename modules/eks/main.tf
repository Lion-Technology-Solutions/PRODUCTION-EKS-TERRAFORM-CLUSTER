resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = var.tags
}

resource "aws_kms_key" "eks" {
  description             = "KMS key for ${var.cluster_name} EKS secret encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${var.environment}-eks-kms"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-${var.environment}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  vpc_config {
    subnet_ids              = var.cluster_subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs     = var.public_access_cidrs
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })

  depends_on = [aws_cloudwatch_log_group.eks]
}

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-${var.environment}-worker-nodes"
  description = "Security group for ${var.cluster_name} EKS managed worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name       = "${var.cluster_name}-${var.environment}-worker-nodes"
    workernode = "liontech-cluster"
  })
}

resource "aws_security_group_rule" "nodes_self_all" {
  type              = "ingress"
  description       = "Allow worker nodes to communicate with each other"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "nodes_from_cluster_https" {
  type                     = "ingress"
  description              = "Allow EKS control plane to reach node kubelets on HTTPS"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "nodes_from_cluster_ephemeral" {
  type                     = "ingress"
  description              = "Allow EKS control plane to reach node ephemeral ports"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "nodeport_ingress" {
  type              = "ingress"
  description       = "Allow internet clients to reach applications exposed with Kubernetes NodePort"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = var.allowed_nodeport_cidrs
  security_group_id = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  description       = "Allow worker nodes outbound internet access"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "cluster_from_nodes_https" {
  type                     = "ingress"
  description              = "Allow worker nodes to reach the Kubernetes API"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nodes.id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_launch_template" "nodes" {
  name_prefix = "${var.cluster_name}-${var.environment}-nodes-"
  description = "Launch template for ${var.cluster_name} EKS managed worker nodes"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = true
      volume_size           = var.node_disk_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    delete_on_termination       = true
    security_groups             = [aws_security_group.nodes.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name       = "${var.cluster_name}-${var.environment}-worker"
      workernode = "liontech-cluster"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name       = "${var.cluster_name}-${var.environment}-worker-volume"
      workernode = "liontech-cluster"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${var.environment}-workers"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.node_subnet_ids
  ami_type        = "AL2_x86_64"
  capacity_type   = var.node_capacity_type
  instance_types  = var.node_instance_types

  launch_template {
    id      = aws_launch_template.nodes.id
    version = "$Latest"
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = var.node_max_unavailable
  }

  labels = merge(var.node_labels, {
    workernode = "liontech-cluster"
  })

  tags = merge(var.tags, {
    Name                                            = "${var.cluster_name}-${var.environment}-workers"
    workernode                                      = "liontech-cluster"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  })

  depends_on = [
    aws_security_group_rule.cluster_from_nodes_https
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

locals {
  cluster_autoscaler_asg_tags = {
    "k8s.io/cluster-autoscaler/enabled"                        = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"            = "owned"
    "k8s.io/cluster-autoscaler/node-template/label/workernode" = "liontech-cluster"
    "k8s.io/cluster-autoscaler/node-template/label/cluster"    = var.cluster_name
    "k8s.io/cluster-autoscaler/node-template/label/workload"   = "production"
  }
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler" {
  for_each = local.cluster_autoscaler_asg_tags

  autoscaling_group_name = aws_eks_node_group.workers.resources[0].autoscaling_groups[0].name

  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = false
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.workers]
}

