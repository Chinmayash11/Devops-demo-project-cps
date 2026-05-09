# Development Environment Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway IPs"
  value       = module.vpc.nat_gateway_ips
}

# ============================================================================
# EKS Cluster Outputs
# ============================================================================

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

# ============================================================================
# Security Outputs
# ============================================================================

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.security.ecr_repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = module.security.ecr_repository_arn
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = module.security.kms_key_id
}

output "db_secret_arn" {
  description = "Database credentials secret ARN"
  value       = module.security.db_secret_arn
}

# ============================================================================
# IAM Outputs
# ============================================================================

output "eks_cluster_role_arn" {
  description = "EKS cluster IAM role ARN"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_group_role_arn" {
  description = "EKS node group IAM role ARN"
  value       = module.iam.eks_node_group_role_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller role ARN"
  value       = module.iam_irsa.aws_load_balancer_controller_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler role ARN"
  value       = module.iam_irsa.cluster_autoscaler_role_arn
}

# ============================================================================
# Connection Information
# ============================================================================

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.security.ecr_repository_url}"
}
