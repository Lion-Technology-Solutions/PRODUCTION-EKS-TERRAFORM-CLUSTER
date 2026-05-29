locals {
  oidc_provider_host = replace(var.cluster_oidc_issuer_url, "https://", "")
}

data "tls_certificate" "oidc" {
  count = var.enabled ? 1 : 0

  url = var.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "this" {
  count = var.enabled ? 1 : 0

  url             = var.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc[0].certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}

data "aws_iam_policy_document" "cluster_autoscaler_assume_role" {
  count = var.enabled ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enabled ? 1 : 0

  name               = "${var.cluster_name}-cluster-autoscaler-irsa"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role[0].json

  tags = var.tags
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  count = var.enabled ? 1 : 0

  statement {
    sid    = "AutoscalingReadOnly"
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AutoscalingWrite"
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enabled ? 1 : 0

  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "Least privilege permissions for Cluster Autoscaler on ${var.cluster_name}"
  policy      = data.aws_iam_policy_document.cluster_autoscaler[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.enabled ? 1 : 0

  role       = aws_iam_role.cluster_autoscaler[0].name
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
}

resource "helm_release" "metrics_server" {
  count = var.enabled ? 1 : 0

  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.metrics_server_chart_version
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      args = [
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port"
      ]
      metrics = {
        enabled = true
      }
    })
  ]
}

resource "helm_release" "cluster_autoscaler" {
  count = var.enabled ? 1 : 0

  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = var.cluster_autoscaler_chart_version
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler[0].arn
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.expander"
    value = "least-waste"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  set {
    name  = "extraArgs.scale-down-enabled"
    value = "true"
  }

  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_autoscaler,
    helm_release.metrics_server
  ]
}

resource "helm_release" "vertical_pod_autoscaler" {
  count = var.enabled && var.vertical_pod_autoscaler_enabled ? 1 : 0

  name             = "vertical-pod-autoscaler"
  repository       = var.vertical_pod_autoscaler_repository
  chart            = var.vertical_pod_autoscaler_chart
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  depends_on = [helm_release.metrics_server]
}

