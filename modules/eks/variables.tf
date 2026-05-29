variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "cluster_subnet_ids" {
  description = "Subnets used by the EKS control plane."
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnets used by the managed node group."
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "EKS cluster IAM role ARN."
  type        = string
}

variable "node_role_arn" {
  description = "EKS worker node IAM role ARN."
  type        = string
}

variable "endpoint_public_access" {
  description = "Enable public EKS API endpoint."
  type        = bool
}

variable "endpoint_private_access" {
  description = "Enable private EKS API endpoint."
  type        = bool
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint."
  type        = list(string)
}

variable "allowed_nodeport_cidrs" {
  description = "CIDRs allowed to reach worker nodes on NodePort ports."
  type        = list(string)
}

variable "associate_public_ip_address" {
  description = "Associate public IP addresses on worker node network interfaces."
  type        = bool
}

variable "node_instance_types" {
  description = "Managed node group instance types."
  type        = list(string)
}

variable "node_capacity_type" {
  description = "Managed node group capacity type."
  type        = string
}

variable "node_disk_size" {
  description = "Worker node root volume size."
  type        = number
}

variable "node_desired_size" {
  description = "Desired worker node count."
  type        = number
}

variable "node_min_size" {
  description = "Minimum worker node count."
  type        = number
}

variable "node_max_size" {
  description = "Maximum worker node count."
  type        = number
}

variable "node_max_unavailable" {
  description = "Maximum unavailable nodes during rolling updates."
  type        = number
}

variable "cloudwatch_log_retention_days" {
  description = "Control plane log retention in days."
  type        = number
}

variable "node_labels" {
  description = "Labels applied to worker nodes."
  type        = map(string)
}

variable "tags" {
  description = "Tags applied to EKS resources."
  type        = map(string)
  default     = {}
}

