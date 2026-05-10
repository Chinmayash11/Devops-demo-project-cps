# IAM Module - Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "EKS OIDC provider URL"
  type        = string
}

variable "eks_oidc_thumbprint" {
  description = "EKS OIDC thumbprint"
  type        = string
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" # AWS OIDC thumbprint (does not change)
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
