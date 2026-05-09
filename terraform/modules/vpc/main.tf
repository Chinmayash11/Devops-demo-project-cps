# VPC Module - Main Configuration
# This module creates a production-grade VPC with:
# - Public and private subnets across multiple AZs
# - NAT Gateways for private subnet internet access
# - Internet Gateway
# - Route tables with proper routing
# - Network ACLs
# - VPC Flow Logs for monitoring

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

  default_tags {
    tags = local.common_tags
  }
}

# ============================================================================
# VPC Resource
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# ============================================================================
# Internet Gateway
# ============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

# ============================================================================
# Public Subnets
# ============================================================================

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                                           = "${var.project_name}-public-subnet-${count.index + 1}"
      "kubernetes.io/role/elb"                       = "1"
      "kubernetes.io/role/internal-elb"              = "1"
    }
  )
}

# ============================================================================
# Private Subnets
# ============================================================================

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name                              = "${var.project_name}-private-subnet-${count.index + 1}"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# ============================================================================
# Elastic IPs for NAT Gateways
# ============================================================================

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-nat-eip-${count.index + 1}"
    }
  )
}

# ============================================================================
# NAT Gateways
# ============================================================================

resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-nat-gw-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# Public Route Table
# ============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-rt"
    }
  )
}

# ============================================================================
# Public Route Table Associations
# ============================================================================

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================================================
# Private Route Tables (one per AZ for NAT Gateway redundancy)
# ============================================================================

resource "aws_route_table" "private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-rt-${count.index + 1}"
    }
  )
}

# ============================================================================
# Private Route Table Associations
# ============================================================================

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ============================================================================
# VPC Flow Logs (for monitoring and troubleshooting)
# ============================================================================

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}"
  retention_in_days = var.vpc_flow_logs_retention_days

  tags = local.common_tags
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-vpc-flow-logs"
    }
  )
}

# ============================================================================
# IAM Role for VPC Flow Logs
# ============================================================================

resource "aws_iam_role" "vpc_flow_logs" {
  name_prefix = "${var.project_name}-vpc-flow-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name_prefix = "${var.project_name}-vpc-flow-logs-"
  role        = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Network ACLs (optional, for additional security)
# ============================================================================

resource "aws_network_acl_rule" "private_ingress" {
  network_acl_id = aws_vpc.main.default_network_acl_id
  rule_number    = 100
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "private_egress" {
  network_acl_id = aws_vpc.main.default_network_acl_id
  rule_number    = 100
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  egress         = true
  from_port      = 0
  to_port        = 0
}
