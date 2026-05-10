# Terraform Configuration for Production Environment
# This configuration uses modules to create a highly available and secure EKS cluster infrastructure

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.50.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
  }

  # Backend settings are supplied by GitHub Actions via -backend-config.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "tls" {}

# ============================================================================
# Local Values
# ============================================================================

locals {
  environment = "prod"
  common_tags = merge(
    var.additional_tags,
    {
      Environment = local.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Workspace   = terraform.workspace
    }
  )
}

# ============================================================================
# VPC Module
# ============================================================================

module "vpc" {
  source = "../../modules/vpc"

  aws_region           = var.aws_region
  project_name         = var.project_name
  environment          = local.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  vpc_flow_logs_retention_days = var.vpc_flow_logs_retention_days

  tags = local.common_tags
}

# ============================================================================
# IAM Module
# ============================================================================

module "iam" {
  source = "../../modules/iam"

  project_name          = var.project_name
  cluster_name          = var.cluster_name
  eks_oidc_provider_url = "" # Will be updated after EKS cluster creation
  eks_oidc_thumbprint   = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
  create_base_iam_roles = true
  enable_irsa           = false

  common_tags = local.common_tags
}

# ============================================================================
# EKS Module
# ============================================================================

module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  subnet_ids         = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  private_subnet_ids = module.vpc.private_subnet_ids

  eks_cluster_role_arn     = module.iam.eks_cluster_role_arn
  eks_node_group_role_arn  = module.iam.eks_node_group_role_arn
  eks_node_group_role_name = module.iam.eks_node_group_role_name

  desired_node_count  = var.desired_node_count
  min_node_count      = var.min_node_count
  max_node_count      = var.max_node_count
  node_instance_types = var.node_instance_types
  node_disk_size      = var.node_disk_size

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs

  log_retention_days = var.log_retention_days

  vpc_cni_role_arn = module.iam.eks_cluster_role_arn
  ebs_csi_role_arn = module.iam.ebs_csi_driver_role_arn

  common_tags = local.common_tags

  depends_on = [module.vpc, module.iam]
}

# ============================================================================
# Security Module
# ============================================================================

module "security" {
  source = "../../modules/security"

  project_name         = var.project_name
  cluster_name         = var.cluster_name
  app_name             = var.app_name
  vpc_id               = module.vpc.vpc_id
  node_group_role_name = module.iam.eks_node_group_role_name

  db_username = var.db_username
  db_password = var.db_password
  db_host     = var.db_host
  db_port     = var.db_port
  db_name     = var.db_name

  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  log_retention_days    = var.log_retention_days

  common_tags = local.common_tags

  depends_on = [module.eks]
}

# ============================================================================
# Update IAM Module with OIDC Provider URL
# ============================================================================

module "iam_irsa" {
  source = "../../modules/iam"

  project_name          = var.project_name
  cluster_name          = var.cluster_name
  eks_oidc_provider_url = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn     = module.eks.oidc_provider_arn
  eks_oidc_thumbprint   = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
  create_base_iam_roles = false
  enable_irsa           = true

  common_tags = local.common_tags

  depends_on = [module.eks]
}
