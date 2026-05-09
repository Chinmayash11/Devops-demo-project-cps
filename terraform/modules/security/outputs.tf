# Security Module - Outputs

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.app.arn
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

output "kms_key_id" {
  description = "KMS key ID for EKS encryption"
  value       = aws_kms_key.eks.id
}

output "kms_key_arn" {
  description = "KMS key ARN for EKS encryption"
  value       = aws_kms_key.eks.arn
}

output "db_secret_arn" {
  description = "ARN of database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "app_ingress_security_group_id" {
  description = "Security group ID for application ingress"
  value       = aws_security_group.app_ingress.id
}

output "app_logs_log_group_name" {
  description = "CloudWatch log group name for application logs"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}
