#!/bin/bash
# Deployment script for EKS cluster setup and application deployment
# This script automates the infrastructure provisioning and application deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
KUBERNETES_DIR="$PROJECT_ROOT/kubernetes"

# Default values
ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"
ACTION="${3:-deploy}"

# ============================================================================
# Functions
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v terraform &> /dev/null || log_error "Terraform is not installed"
    command -v kubectl &> /dev/null || log_error "kubectl is not installed"
    command -v aws &> /dev/null || log_error "AWS CLI is not installed"
    command -v helm &> /dev/null || log_warn "Helm is not installed (optional)"
    
    log_info "All prerequisites met"
}

init_terraform() {
    log_info "Initializing Terraform for environment: $ENVIRONMENT"
    
    cd "$TERRAFORM_DIR/environments/$ENVIRONMENT"
    terraform init \
        -backend-config="key=terraform-${ENVIRONMENT}.tfstate" \
        -backend-config="region=${AWS_REGION}"
    
    log_info "Terraform initialized successfully"
}

validate_terraform() {
    log_info "Validating Terraform configuration..."
    
    cd "$TERRAFORM_DIR/environments/$ENVIRONMENT"
    terraform validate
    
    log_info "Terraform validation passed"
}

plan_terraform() {
    log_info "Planning Terraform deployment..."
    
    cd "$TERRAFORM_DIR/environments/$ENVIRONMENT"
    terraform plan -out=tfplan
    
    log_info "Terraform plan created"
}

apply_terraform() {
    log_info "Applying Terraform configuration..."
    
    cd "$TERRAFORM_DIR/environments/$ENVIRONMENT"
    terraform apply tfplan
    
    log_info "Terraform apply completed"
}

configure_kubectl() {
    log_info "Configuring kubectl..."
    
    CLUSTER_NAME=$(cd "$TERRAFORM_DIR/environments/$ENVIRONMENT" && terraform output -raw eks_cluster_name)
    
    aws eks update-kubeconfig \
        --name "$CLUSTER_NAME" \
        --region "$AWS_REGION"
    
    log_info "kubectl configured successfully"
}

deploy_kubernetes() {
    log_info "Deploying Kubernetes resources for environment: $ENVIRONMENT"
    
    if [ "$ENVIRONMENT" == "dev" ]; then
        OVERLAY="overlays/dev"
    elif [ "$ENVIRONMENT" == "prod" ]; then
        OVERLAY="overlays/prod"
    else
        log_error "Unknown environment: $ENVIRONMENT"
    fi
    
    cd "$KUBERNETES_DIR"
    kubectl apply -k "$OVERLAY"
    
    log_info "Kubernetes deployment completed"
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check pod status
    log_info "Pod status:"
    kubectl get pods -n production-app
    
    # Check service status
    log_info "Service status:"
    kubectl get svc -n production-app
    
    # Check deployment status
    log_info "Deployment status:"
    kubectl get deployment -n production-app
    
    log_info "Deployment verification completed"
}

print_usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [AWS_REGION] [ACTION]

Arguments:
    ENVIRONMENT   - Environment to deploy to (dev or prod) - default: dev
    AWS_REGION    - AWS region - default: us-east-1
    ACTION        - Action to perform (deploy, destroy, plan) - default: deploy

Examples:
    $0                          # Deploy to dev in us-east-1
    $0 prod us-west-2           # Deploy to prod in us-west-2
    $0 dev us-east-1 plan       # Plan deployment to dev
    $0 prod us-east-1 destroy   # Destroy prod infrastructure

EOF
}

# ============================================================================
# Main
# ============================================================================

case "$ACTION" in
    deploy)
        check_prerequisites
        init_terraform
        validate_terraform
        plan_terraform
        apply_terraform
        configure_kubectl
        deploy_kubernetes
        verify_deployment
        log_info "Deployment completed successfully!"
        ;;
    plan)
        check_prerequisites
        init_terraform
        validate_terraform
        plan_terraform
        log_info "Plan completed. Review the plan and run with ACTION=deploy to apply."
        ;;
    destroy)
        log_warn "This will destroy all infrastructure for environment: $ENVIRONMENT"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Destroy cancelled"
            exit 0
        fi
        
        cd "$TERRAFORM_DIR/environments/$ENVIRONMENT"
        terraform destroy -auto-approve
        log_info "Infrastructure destroyed"
        ;;
    *)
        log_error "Unknown action: $ACTION"
        print_usage
        exit 1
        ;;
esac
