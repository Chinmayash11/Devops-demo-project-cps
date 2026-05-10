# Production Environment Variables

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
  default     = "devops-app-prod-eks"
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
# VPC Configuration (Multi-AZ for HA)
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones (3 AZs for HA)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
}

variable "vpc_flow_logs_retention_days" {
  description = "VPC Flow Logs retention days"
  type        = number
  default     = 90
}

# ============================================================================
# EKS Node Configuration (HA setup)
# ============================================================================

variable "desired_node_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 6
}

variable "min_node_count" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 3
}

variable "max_node_count" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 20
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes (production grade)"
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_disk_size" {
  description = "EBS volume size for worker nodes in GB"
  type        = number
  default     = 100
}

# ============================================================================
# Cluster Access Configuration (Restricted for Production)
# ============================================================================

variable "endpoint_public_access" {
  description = "Enable public access to cluster API"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed for public API access"
  type        = list(string)
  default     = []
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
  default     = "proddbadmin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "ProdPassword123!@#SecurePassword"
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = "postgres-prod.example.com"
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "devops_prod_db"
}

# ============================================================================
# Network Configuration (Restricted)
# ============================================================================

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed for ingress (restricted for production)"
  type        = list(string)
  default     = ["10.1.0.0/16"] # Only from within VPC
}

# ============================================================================
# Logging Configuration (Longer retention for compliance)
# ============================================================================

variable "log_retention_days" {
  description = "CloudWatch logs retention days"
  type        = number
  default     = 365 # 1 year for compliance
}

# ============================================================================
# Tags
# ============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform  = "true"
    CostCenter = "Operations"
    Compliance = "Required"
  }
}
