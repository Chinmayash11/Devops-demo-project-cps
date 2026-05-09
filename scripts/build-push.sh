#!/bin/bash
# Docker build and push script
# Builds the Docker image and pushes it to AWS ECR

set -e

# Configuration
IMAGE_NAME="${IMAGE_NAME:-production-app}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
DOCKERFILE="${DOCKERFILE:-./Dockerfile}"
BUILD_CONTEXT="${BUILD_CONTEXT:-$(pwd)}"
TAG="${TAG:-latest}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
if [ -z "$AWS_ACCOUNT_ID" ]; then
    log_error "AWS_ACCOUNT_ID environment variable is not set"
fi

# Get ECR repository URL
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}"

log_info "Building Docker image: $IMAGE_NAME"
docker build -f "$DOCKERFILE" -t "${IMAGE_NAME}:${TAG}" "$BUILD_CONTEXT"

log_info "Tagging image: ${ECR_REPO}:${TAG}"
docker tag "${IMAGE_NAME}:${TAG}" "${ECR_REPO}:${TAG}"
docker tag "${IMAGE_NAME}:${TAG}" "${ECR_REPO}:latest"

log_info "Logging into ECR"
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REPO"

log_info "Pushing image to ECR"
docker push "${ECR_REPO}:${TAG}"
docker push "${ECR_REPO}:latest"

log_info "Build and push completed successfully"
log_info "Image pushed to: ${ECR_REPO}:${TAG}"
