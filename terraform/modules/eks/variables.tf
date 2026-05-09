# EKS Module - Variables

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only letters, numbers, and hyphens"
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
  validation {
    condition     = can(regex("^1\\.[0-9]{1,2}$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format 1.XX"
  }
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster (public and private)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS node groups"
  type        = list(string)
}

variable "eks_cluster_role_arn" {
  description = "ARN of IAM role for EKS cluster"
  type        = string
}

variable "eks_node_group_role_arn" {
  description = "ARN of IAM role for EKS node groups"
  type        = string
}

variable "eks_node_group_role_name" {
  description = "Name of IAM role for EKS node groups"
  type        = string
}

variable "desired_node_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
  validation {
    condition     = var.desired_node_count > 0 && var.desired_node_count <= 100
    error_message = "Desired node count must be between 1 and 100"
  }
}

variable "min_node_count" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.min_node_count > 0
    error_message = "Minimum node count must be at least 1"
  }
}

variable "max_node_count" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
  validation {
    condition     = var.max_node_count > 0
    error_message = "Maximum node count must be at least 1"
  }
}

variable "node_instance_types" {
  description = "List of instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_disk_size" {
  description = "EBS volume size for worker nodes in GB"
  type        = number
  default     = 50
  validation {
    condition     = var.node_disk_size >= 20
    error_message = "Node disk size must be at least 20 GB"
  }
}

variable "endpoint_public_access" {
  description = "Enable public access to cluster API"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks for public API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "CloudWatch logs retention days"
  type        = number
  default     = 30
  validation {
    condition     = var.log_retention_days > 0
    error_message = "Log retention days must be greater than 0"
  }
}

variable "vpc_cni_version" {
  description = "Version of AWS VPC CNI add-on"
  type        = string
  default     = null
}

variable "vpc_cni_role_arn" {
  description = "ARN of IAM role for VPC CNI"
  type        = string
}

variable "coredns_version" {
  description = "Version of CoreDNS add-on"
  type        = string
  default     = null
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy add-on"
  type        = string
  default     = null
}

variable "ebs_csi_version" {
  description = "Version of EBS CSI driver add-on"
  type        = string
  default     = null
}

variable "ebs_csi_role_arn" {
  description = "ARN of IAM role for EBS CSI driver"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
