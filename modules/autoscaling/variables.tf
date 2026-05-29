variable "enabled" {
  description = "Install autoscaling add-ons."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "cluster_autoscaler_chart_version" {
  description = "Cluster Autoscaler Helm chart version."
  type        = string
}

variable "metrics_server_chart_version" {
  description = "Metrics Server Helm chart version."
  type        = string
}

variable "vertical_pod_autoscaler_enabled" {
  description = "Install optional Vertical Pod Autoscaler."
  type        = bool
}

variable "vertical_pod_autoscaler_repository" {
  description = "VPA Helm repository URL."
  type        = string
}

variable "vertical_pod_autoscaler_chart" {
  description = "VPA Helm chart name."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}

