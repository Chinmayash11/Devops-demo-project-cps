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

variable "oidc_provider_arn" {
  description = "Existing EKS OIDC provider ARN to use for IRSA roles"
  type        = string
  default     = ""
}

variable "eks_oidc_thumbprint" {
  description = "EKS OIDC thumbprint"
  type        = string
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" # AWS OIDC thumbprint (does not change)
}

variable "create_base_iam_roles" {
  description = "Whether to create the base EKS cluster and node group IAM roles"
  type        = bool
  default     = true
}

variable "enable_irsa" {
  description = "Whether to create IAM roles for service accounts"
  type        = bool
  default     = false
}

variable "create_oidc_provider" {
  description = "Whether this module should create the OIDC provider"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
