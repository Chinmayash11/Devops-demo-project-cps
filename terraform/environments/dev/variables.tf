# Development Environment Variables

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "devops-app"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "devops-app-dev-eks"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "devops-app"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

# ============================================================================
# VPC Configuration
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "vpc_flow_logs_retention_days" {
  description = "VPC Flow Logs retention days"
  type        = number
  default     = 7
}

# ============================================================================
# EKS Node Configuration
# ============================================================================

variable "desired_node_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_disk_size" {
  description = "EBS volume size for worker nodes in GB"
  type        = number
  default     = 50
}

# ============================================================================
# Cluster Access Configuration
# ============================================================================

variable "endpoint_public_access" {
  description = "Enable public access to cluster API"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed for public API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
  default     = "dbadmin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "DevPassword123!"
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = "postgres.example.com"
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "devops_db"
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed for ingress"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ============================================================================
# Logging Configuration
# ============================================================================

variable "log_retention_days" {
  description = "CloudWatch logs retention days"
  type        = number
  default     = 7
}

# ============================================================================
# Tags
# ============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform = "true"
    CostCenter = "Engineering"
  }
}
