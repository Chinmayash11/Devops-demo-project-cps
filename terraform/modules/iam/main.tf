# IAM Module - Main Configuration
# This module creates IAM roles and policies for:
# - EKS cluster service role
# - EKS node group roles
# - OIDC provider for IRSA (IAM Roles for Service Accounts)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.50.0"
    }
  }
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  iam_name_prefix_max_length = 38

  iam_name_prefixes = {
    eks_cluster         = "${substr(var.project_name, 0, local.iam_name_prefix_max_length - length("-eks-cl-"))}-eks-cl-"
    eks_node_group      = "${substr(var.project_name, 0, local.iam_name_prefix_max_length - length("-eks-ng-"))}-eks-ng-"
    eks_node_cloudwatch = "${substr(var.project_name, 0, local.iam_name_prefix_max_length - length("-cw-"))}-cw-"
    eks_node_profile    = "${substr(var.project_name, 0, local.iam_name_prefix_max_length - length("-eks-node-"))}-eks-node-"
    alb_controller      = "${substr(var.project_name, 0, local.iam_name_prefix_max_length - length("-alb-"))}-alb-"
    cluster_autoscaler  = "${substr(var.project_name, 0, local.iam_name_prefix_max_length - length("-ca-"))}-ca-"
    ebs_csi_driver      = "${substr(var.project_name, 0, local.iam_name_prefix_max_length - length("-ebs-csi-"))}-ebs-csi-"
  }

  irsa_count        = var.enable_irsa ? 1 : 0
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].arn : var.oidc_provider_arn
  oidc_provider_url = replace(var.eks_oidc_provider_url, "https://", "")
}

# ============================================================================
# EKS Cluster IAM Role
# ============================================================================

resource "aws_iam_role" "eks_cluster_role" {
  count       = var.create_base_iam_roles ? 1 : 0
  name_prefix = local.iam_name_prefixes.eks_cluster

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# ============================================================================
# EKS Cluster IAM Policy Attachment
# ============================================================================

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.create_base_iam_roles ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role[0].name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  count      = var.create_base_iam_roles ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role[0].name
}

# ============================================================================
# EKS Node Group IAM Role
# ============================================================================

resource "aws_iam_role" "eks_node_group_role" {
  count       = var.create_base_iam_roles ? 1 : 0
  name_prefix = local.iam_name_prefixes.eks_node_group

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# ============================================================================
# EKS Node Group IAM Policy Attachments
# ============================================================================

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  count      = var.create_base_iam_roles ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = var.create_base_iam_roles ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  count      = var.create_base_iam_roles ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "eks_ssm_managed_instance_core" {
  count      = var.create_base_iam_roles ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group_role[0].name
}

# ============================================================================
# Custom Policy for CloudWatch Logs and Container Insights
# ============================================================================

resource "aws_iam_role_policy" "eks_node_cloudwatch_policy" {
  count       = var.create_base_iam_roles ? 1 : 0
  name_prefix = local.iam_name_prefixes.eks_node_cloudwatch
  role        = aws_iam_role.eks_node_group_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# IAM Instance Profile for EKS Nodes
# ============================================================================

resource "aws_iam_instance_profile" "eks_node_group" {
  count       = var.create_base_iam_roles ? 1 : 0
  name_prefix = local.iam_name_prefixes.eks_node_profile
  role        = aws_iam_role.eks_node_group_role[0].name
}

# ============================================================================
# OIDC Provider for IAM Roles for Service Accounts (IRSA)
# ============================================================================

resource "aws_iam_openid_connect_provider" "eks" {
  count           = var.create_oidc_provider ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.eks_oidc_thumbprint]
  url             = var.eks_oidc_provider_url

  tags = var.common_tags
}

# ============================================================================
# IAM Role for AWS Load Balancer Controller
# ============================================================================

resource "aws_iam_role" "aws_load_balancer_controller" {
  count       = local.irsa_count
  name_prefix = local.iam_name_prefixes.alb_controller

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "aws_load_balancer_controller" {
  count       = local.irsa_count
  name_prefix = local.iam_name_prefixes.alb_controller
  role        = aws_iam_role.aws_load_balancer_controller[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elbv2:CreateLoadBalancer",
          "elbv2:CreateTargetGroup",
          "elbv2:CreateListener",
          "elbv2:DeleteLoadBalancer",
          "elbv2:DeleteTargetGroup",
          "elbv2:DeleteListener",
          "elbv2:DescribeLoadBalancers",
          "elbv2:DescribeTargetGroups",
          "elbv2:DescribeListeners",
          "elbv2:DescribeLoadBalancerAttributes",
          "elbv2:DescribeTargetGroupAttributes",
          "elbv2:DescribeTags",
          "elbv2:ModifyLoadBalancerAttributes",
          "elbv2:ModifyTargetGroupAttributes",
          "elbv2:ModifyListener",
          "elbv2:RegisterTargets",
          "elbv2:DeregisterTargets",
          "elbv2:AddTags",
          "elbv2:RemoveTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstanceAttribute",
          "ec2:ModifyInstanceAttribute"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# IAM Role for Cluster Autoscaler
# ============================================================================

resource "aws_iam_role" "cluster_autoscaler" {
  count       = local.irsa_count
  name_prefix = local.iam_name_prefixes.cluster_autoscaler

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count       = local.irsa_count
  name_prefix = local.iam_name_prefixes.cluster_autoscaler
  role        = aws_iam_role.cluster_autoscaler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      }
    ]
  })
}

# ============================================================================
# IAM Role for EBS CSI Driver
# ============================================================================

resource "aws_iam_role" "ebs_csi_driver" {
  count       = local.irsa_count
  name_prefix = local.iam_name_prefixes.ebs_csi_driver

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count      = local.irsa_count
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}



