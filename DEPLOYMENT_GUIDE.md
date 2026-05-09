# 1. Set AWS credentials and environment
export AWS_ACCOUNT_ID=<your-aws-account-id>
export AWS_REGION=us-east-1
export ENVIRONMENT=dev

# 2. Deploy infrastructure (VPC, EKS, IAM, Security)
bash scripts/deploy.sh dev us-east-1 deploy

# 3. Build and push Docker image to ECR
export IMAGE_NAME=production-app
bash scripts/build-push.sh

# 4. Deploy application to Kubernetes
kubectl apply -k kubernetes/overlays/dev

# 5. Verify deployment
bash scripts/health-check.sh# Deployment Guide

## Project Overview

This is a production-grade DevOps project that deploys a containerized Flask application on AWS EKS (Elastic Kubernetes Service) with comprehensive monitoring, logging, and infrastructure as code.

## Architecture Components

### Application
- **Flask API**: Python web application with Prometheus metrics and health checks
- **Docker**: Multi-stage containerized build
- **ECR**: Elastic Container Registry for image storage

### Infrastructure
- **VPC**: Custom Virtual Private Cloud with public/private subnets across multiple AZs
- **EKS**: Managed Kubernetes cluster with auto-scaling node groups
- **IAM**: Role-based access control and IRSA (IAM Roles for Service Accounts)
- **Security**: KMS encryption, security groups, network policies

### Kubernetes
- **Deployments**: Stateless application pods with rolling updates
- **Services**: Load balancer and internal service exposure
- **Ingress**: API gateway with routing rules
- **HPA**: Horizontal Pod Autoscaler based on CPU/memory metrics
- **PDB**: Pod Disruption Budget for availability

### Monitoring
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **CloudWatch**: AWS native logging and monitoring
- **Fluent Bit**: Log aggregation from containers

## Prerequisites

### Required Tools
- Terraform >= 1.0
- kubectl >= 1.24
- AWS CLI >= 2.0
- Docker >= 20.0
- Helm >= 3.0 (optional, for Prometheus/Grafana)

### AWS Requirements
- AWS Account with appropriate permissions
- IAM user with programmatic access
- Configured AWS CLI credentials

## Quick Start

### 1. Clone Repository
\`\`\`bash
git clone <repository-url>
cd <project-directory>
\`\`\`

### 2. Configure Environment Variables
\`\`\`bash
export AWS_ACCOUNT_ID=<your-account-id>
export AWS_REGION=us-east-1
export ENVIRONMENT=dev
\`\`\`

### 3. Deploy Infrastructure
\`\`\`bash
bash scripts/deploy.sh dev us-east-1 deploy
\`\`\`

### 4. Build and Push Application Image
\`\`\`bash
export IMAGE_NAME=production-app
bash scripts/build-push.sh
\`\`\`

### 5. Deploy Application
\`\`\`bash
kubectl apply -k kubernetes/overlays/dev
\`\`\`

## Deployment Steps in Detail

### Step 1: Terraform Backend Setup
\`\`\`bash
cd terraform/backend
terraform init
terraform apply
\`\`\`

### Step 2: VPC and Security Infrastructure
\`\`\`bash
cd terraform/environments/dev
terraform init -backend-config=\
    -backend-config="key=terraform-dev.tfstate" \
    -backend-config="region=us-east-1"
terraform plan
terraform apply
\`\`\`

### Step 3: Configure kubectl
\`\`\`bash
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1
\`\`\`

### Step 4: Deploy Kubernetes Resources
\`\`\`bash
# For dev environment
kubectl apply -k kubernetes/overlays/dev

# For prod environment
kubectl apply -k kubernetes/overlays/prod
\`\`\`

### Step 5: Verify Deployment
\`\`\`bash
# Check pods
kubectl get pods -n production-app

# Check services
kubectl get svc -n production-app

# Check deployment status
kubectl get deployment -n production-app

# Get load balancer URL
kubectl get svc production-app -n production-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
\`\`\`

## Configuration

### Environment Variables

#### Development
- 1 replica per pod
- Lower resource limits
- DEBUG logging enabled
- Profiling enabled

#### Production
- 5 replicas per pod
- Higher resource limits
- WARN logging level
- Profiling disabled
- 3 AZ deployment for HA

### Application Configuration
Edit \`kubernetes/base/configmap.yaml\` to customize:
- LOG_LEVEL
- APP_NAME
- ENVIRONMENT
- METRICS_PORT

### Kubernetes Patching
- Dev patches in \`kubernetes/overlays/dev/deployment-patch.yaml\`
- Prod patches in \`kubernetes/overlays/prod/deployment-patch.yaml\`

## Monitoring and Logging

### Prometheus
Access Prometheus dashboard:
\`\`\`bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090
\`\`\`

### Grafana
Access Grafana dashboards:
\`\`\`bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# Visit http://localhost:3000
\`\`\`

### CloudWatch Logs
\`\`\`bash
aws logs tail /aws/eks/devops-app-dev-eks/cluster --follow
\`\`\`

### Application Metrics
\`\`\`bash
# Get application metrics
kubectl port-forward -n production-app svc/production-app 5000:80
curl http://localhost:5000/metrics
\`\`\`

## Health Checks

### Application Endpoints
- \`GET /health\` - Basic health check
- \`GET /health/ready\` - Readiness probe
- \`GET /health/live\` - Liveness probe
- \`GET /metrics\` - Prometheus metrics
- \`GET /api/v1/config\` - Configuration info

### Verify Health
\`\`\`bash
kubectl exec -it <pod-name> -n production-app -- \
    curl http://localhost:5000/health
\`\`\`

## Scaling

### Horizontal Pod Autoscaling
The HPA is configured to scale based on:
- CPU utilization > 70%
- Memory utilization > 80%
- Custom metrics (http_requests_per_second > 1000)

Check HPA status:
\`\`\`bash
kubectl get hpa -n production-app
kubectl describe hpa production-app-hpa -n production-app
\`\`\`

### Manual Scaling
\`\`\`bash
kubectl scale deployment production-app --replicas=5 -n production-app
\`\`\`

## Troubleshooting

### Check Pod Status
\`\`\`bash
kubectl describe pod <pod-name> -n production-app
kubectl logs <pod-name> -n production-app --tail=100
\`\`\`

### Check Node Status
\`\`\`bash
kubectl get nodes
kubectl describe node <node-name>
\`\`\`

### View Events
\`\`\`bash
kubectl get events -n production-app
\`\`\`

### SSH into Node (if needed)
\`\`\`bash
# Create debug pod
kubectl run -it --image=busybox debug --restart=Never -- sh
\`\`\`

## Maintenance

### Updating Application
\`\`\`bash
# Build and push new image
docker build -t <image>:<new-tag> .
docker push <ecr-url>:<new-tag>

# Update deployment
kubectl set image deployment/production-app \
    app=<ecr-url>:<new-tag> -n production-app
\`\`\`

### Updating Kubernetes Version
\`\`\`bash
# Update variables.tf
# Run terraform apply
\`\`\`

### Backing Up State
\`\`\`bash
# Terraform state is automatically versioned in S3
# To backup manually:
aws s3 cp s3://<bucket>/terraform.tfstate ./backup-terraform.tfstate
\`\`\`

## Cleanup

### Destroy All Resources
\`\`\`bash
bash scripts/deploy.sh prod us-east-1 destroy
\`\`\`

## Cost Optimization

- Use spot instances for non-critical workloads
- Enable cluster autoscaler for right-sizing
- Configure pod disruption budgets
- Use reserved instances for stable baseline load
- Monitor CloudWatch for cost anomalies

## Security Best Practices

- Enable Pod Security Policies
- Use Network Policies to restrict traffic
- Encrypt secrets at rest and in transit
- Enable audit logging
- Use IAM roles with least privilege
- Scan container images for vulnerabilities
- Use private ECR repositories

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [Flask Documentation](https://flask.palletsprojects.com/)
