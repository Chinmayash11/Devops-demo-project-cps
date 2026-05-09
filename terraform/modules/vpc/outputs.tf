# VPC Module - Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "Public subnets map with availability zones"
  value = {
    for i, subnet in aws_subnet.public : var.availability_zones[i] => {
      subnet_id = subnet.id
      cidr_block = subnet.cidr_block
    }
  }
}

output "private_subnets" {
  description = "Private subnets map with availability zones"
  value = {
    for i, subnet in aws_subnet.private : var.availability_zones[i] => {
      subnet_id = subnet.id
      cidr_block = subnet.cidr_block
    }
  }
}

output "nat_gateway_ips" {
  description = "Elastic IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = aws_route_table.private[*].id
}

output "vpc_flow_logs_log_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}
