# VPC Module - Variables

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  validation {
    condition     = length(var.project_name) <= 32
    error_message = "Project name must be less than 32 characters"
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block"
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 4
    error_message = "Must specify between 2 and 4 availability zones"
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Must specify at least 2 public subnet CIDR blocks"
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "Must specify at least 2 private subnet CIDR blocks"
  }
}

variable "vpc_flow_logs_retention_days" {
  description = "CloudWatch Logs retention days for VPC Flow Logs"
  type        = number
  default     = 30
  validation {
    condition     = var.vpc_flow_logs_retention_days > 0
    error_message = "Retention days must be greater than 0"
  }
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
