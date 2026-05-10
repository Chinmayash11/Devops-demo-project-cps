# IAM Module - Outputs

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = try(aws_iam_role.eks_cluster_role[0].arn, "")
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = try(aws_iam_role.eks_cluster_role[0].name, "")
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = try(aws_iam_role.eks_node_group_role[0].arn, "")
}

output "eks_node_group_role_name" {
  description = "Name of the EKS node group IAM role"
  value       = try(aws_iam_role.eks_node_group_role[0].name, "")
}

output "eks_node_instance_profile_arn" {
  description = "ARN of the EKS node instance profile"
  value       = try(aws_iam_instance_profile.eks_node_group[0].arn, "")
}

output "eks_node_instance_profile_name" {
  description = "Name of the EKS node instance profile"
  value       = try(aws_iam_instance_profile.eks_node_group[0].name, "")
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].arn : var.oidc_provider_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = try(aws_iam_role.aws_load_balancer_controller[0].arn, "")
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role"
  value       = try(aws_iam_role.cluster_autoscaler[0].arn, "")
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI Driver IAM role"
  value       = try(aws_iam_role.ebs_csi_driver[0].arn, "")
}
