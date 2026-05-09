# Security Module - Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "app_name" {
  description = "Application name for ECR repository"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "node_group_role_name" {
  description = "EKS node group IAM role name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = "localhost"
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "app_db"
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed for ingress"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "CloudWatch logs retention days"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
