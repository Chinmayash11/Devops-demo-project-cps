# Remote Backend Configuration for Terraform
# This creates S3 bucket and DynamoDB table for state management
# Run this before initializing main Terraform configurations

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# Variables
# ============================================================================

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

# ============================================================================
# S3 Bucket for Terraform State
# ============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket_prefix = "${var.project_name}-terraform-state-"

  tags = {
    Name    = "${var.project_name}-terraform-state"
    Purpose = "Terraform State"
  }
}

# Enable versioning for state file history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for state file (contains sensitive data)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to state file
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable logging for state file access
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "state-access-logs/"
}

# Logging bucket for state file access logs
resource "aws_s3_bucket" "terraform_state_logs" {
  bucket_prefix = "${var.project_name}-terraform-logs-"

  tags = {
    Name    = "${var.project_name}-terraform-logs"
    Purpose = "Terraform State Access Logs"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_lock" {
  name           = "${var.project_name}-terraform-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  server_side_encryption {
    enabled = true
  }
  
  tags = {
    Name    = "${var.project_name}-terraform-lock"
    Purpose = "Terraform State Lock"
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "s3_bucket_name" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_lock.id
}

output "backend_config" {
  description = "Backend configuration for terraform init"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    key            = "terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_lock.id
    encrypt        = true
  }
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# DynamoDB Table for State Locking
# ============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name             = "${var.project_name}-terraform-locks"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name    = "${var.project_name}-terraform-locks"
    Purpose = "Terraform State Locking"
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "s3_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_config" {
  description = "Backend configuration to use in main Terraform files"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    region         = var.aws_region
  }
}

output "backend_config_command" {
  description = "Terraform init command with backend configuration"
  value       = "terraform init -backend-config='bucket=${aws_s3_bucket.terraform_state.id}' -backend-config='dynamodb_table=${aws_dynamodb_table.terraform_locks.name}' -backend-config='key=<environment>/terraform.tfstate' -backend-config='region=${var.aws_region}'"
}
