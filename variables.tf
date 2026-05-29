variable "aws_region" {
  description = "AWS region where the production EKS cluster will be created."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "liontech"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4 for this module."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks. Must have at least az_count entries."
  type        = list(string)
  default     = ["10.50.0.0/20", "10.50.16.0/20", "10.50.32.0/20"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks. Must have at least az_count entries."
  type        = list(string)
  default     = ["10.50.64.0/20", "10.50.80.0/20", "10.50.96.0/20"]
}

variable "enable_nat_gateway" {
  description = "Create NAT gateways so private subnets have outbound internet access."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. False is more available; true is cheaper."
  type        = bool
  default     = false
}

variable "node_subnet_type" {
  description = "Subnet type for worker nodes. Public enables direct NodePort access from the internet."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.node_subnet_type)
    error_message = "node_subnet_type must be either public or private."
  }
}

variable "endpoint_public_access" {
  description = "Enable public endpoint access for the EKS API server."
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Enable private endpoint access for the EKS API server."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_nodeport_cidrs" {
  description = "CIDR blocks allowed to reach worker nodes on Kubernetes NodePort ports 30000-32767."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "node_capacity_type" {
  description = "Capacity type for EKS managed nodes."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_disk_size" {
  description = "Root disk size in GiB for worker nodes."
  type        = number
  default     = 80
}

variable "node_desired_size" {
  description = "Desired worker node count."
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum worker node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum worker node count used by Cluster Autoscaler."
  type        = number
  default     = 8
}

variable "node_max_unavailable" {
  description = "Maximum unavailable nodes during managed node group updates."
  type        = number
  default     = 1
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention for EKS control plane logs."
  type        = number
  default     = 30
}

variable "node_labels" {
  description = "Kubernetes labels applied to every managed worker node."
  type        = map(string)
  default = {
    workernode = "liontech-cluster"
    cluster    = "liontech"
    workload   = "production"
  }
}

variable "enable_autoscaling_addons" {
  description = "Install Cluster Autoscaler and Metrics Server using Helm."
  type        = bool
  default     = true
}

variable "cluster_autoscaler_chart_version" {
  description = "Helm chart version for Cluster Autoscaler."
  type        = string
  default     = "9.43.2"
}

variable "metrics_server_chart_version" {
  description = "Helm chart version for Metrics Server."
  type        = string
  default     = "3.12.2"
}

variable "enable_vertical_pod_autoscaler" {
  description = "Install Vertical Pod Autoscaler chart if the organization maintains the configured VPA chart repository."
  type        = bool
  default     = false
}

variable "vertical_pod_autoscaler_repository" {
  description = "Helm repository for the optional Vertical Pod Autoscaler chart."
  type        = string
  default     = "https://cowboysysop.github.io/charts/"
}

variable "vertical_pod_autoscaler_chart" {
  description = "Optional VPA Helm chart name."
  type        = string
  default     = "vertical-pod-autoscaler"
}

variable "tags" {
  description = "Additional tags merged into all AWS resources."
  type        = map(string)
  default     = {}
}

