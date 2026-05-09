# EKS Module - Outputs

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "EKS cluster platform version"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster"
  value       = try(aws_eks_cluster.main.identity[0].oidc[0].issuer, "")
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = try(aws_iam_openid_connect_provider.eks.arn, "")
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.main.status
}

output "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "nodes_security_group_id" {
  description = "Security group ID of the EKS nodes"
  value       = aws_security_group.eks_nodes.id
}

output "cluster_log_group_name" {
  description = "CloudWatch log group name for EKS cluster logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "container_insights_log_group_name" {
  description = "CloudWatch log group name for Container Insights"
  value       = aws_cloudwatch_log_group.container_insights.name
}
