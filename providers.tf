provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_eks_cluster" "this" {
  count = var.configure_kubernetes_provider ? 1 : 0

  name = module.eks.cluster_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  count = var.configure_kubernetes_provider ? 1 : 0

  name = module.eks.cluster_name

  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = var.configure_kubernetes_provider ? data.aws_eks_cluster.this[0].endpoint : null
  cluster_ca_certificate = var.configure_kubernetes_provider ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : null
  token                  = var.configure_kubernetes_provider ? data.aws_eks_cluster_auth.this[0].token : null
}

provider "helm" {
  kubernetes {
    host                   = var.configure_kubernetes_provider ? data.aws_eks_cluster.this[0].endpoint : null
    cluster_ca_certificate = var.configure_kubernetes_provider ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : null
    token                  = var.configure_kubernetes_provider ? data.aws_eks_cluster_auth.this[0].token : null
  }
}
