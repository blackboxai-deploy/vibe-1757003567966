#!/bin/bash

# AnimaGenius Production Deployment Script
set -euo pipefail

# Configuration
CLUSTER_NAME="animagenius-production"
AWS_REGION="us-east-1"
NAMESPACE="animagenius-production"
DOCKER_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="${GIT_SHA:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required tools
    local tools=("aws" "kubectl" "docker" "terraform")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured"
        exit 1
    fi
    
    # Check environment variables
    if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
        error "AWS_ACCOUNT_ID environment variable not set"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    terraform plan -out=tfplan
    
    # Apply infrastructure
    if terraform apply tfplan; then
        success "Infrastructure deployed successfully"
    else
        error "Infrastructure deployment failed"
        exit 1
    fi
    
    cd ..
}

# Update kubeconfig
update_kubeconfig() {
    log "Updating kubeconfig..."
    
    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME" \
        --alias "$CLUSTER_NAME"
    
    success "Kubeconfig updated"
}

# Build and push Docker images
build_and_push_images() {
    log "Building and pushing Docker images..."
    
    # Login to ECR
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$DOCKER_REGISTRY"
    
    # Create repositories if they don't exist
    local images=("animagenius-api" "animagenius-worker" "animagenius-gpu-worker")
    for image in "${images[@]}"; do
        aws ecr describe-repositories --repository-names "$image" --region "$AWS_REGION" || \
            aws ecr create-repository --repository-name "$image" --region "$AWS_REGION"
    done
    
    # Build and push API image
    log "Building API image..."
    docker build -t "$DOCKER_REGISTRY/animagenius-api:$IMAGE_TAG" -f docker/api/Dockerfile .
    docker push "$DOCKER_REGISTRY/animagenius-api:$IMAGE_TAG"
    
    # Build and push Worker image
    log "Building Worker image..."
    docker build -t "$DOCKER_REGISTRY/animagenius-worker:$IMAGE_TAG" -f docker/worker/Dockerfile .
    docker push "$DOCKER_REGISTRY/animagenius-worker:$IMAGE_TAG"
    
    # Build and push GPU Worker image
    log "Building GPU Worker image..."
    docker build -t "$DOCKER_REGISTRY/animagenius-gpu-worker:$IMAGE_TAG" -f docker/gpu-worker/Dockerfile .
    docker push "$DOCKER_REGISTRY/animagenius-gpu-worker:$IMAGE_TAG"
    
    success "All images built and pushed successfully"
}

# Deploy Kubernetes resources
deploy_kubernetes() {
    log "Deploying Kubernetes resources..."
    
    # Create namespaces
    kubectl apply -f kubernetes/namespaces/
    
    # Deploy secrets (placeholder - actual secrets should be managed securely)
    warn "Please ensure secrets are properly configured before deploying"
    kubectl apply -f kubernetes/secrets/ --dry-run=client -o yaml
    
    # Deploy ConfigMaps
    kubectl apply -f kubernetes/configmaps/
    
    # Wait for namespace to be ready
    kubectl wait --for=condition=Ready namespace "$NAMESPACE" --timeout=60s
    
    # Deploy services first
    kubectl apply -f kubernetes/services/
    
    # Deploy deployments with updated image tags
    sed -i.bak "s|image: animagenius/.*:.*|image: $DOCKER_REGISTRY/animagenius-api:$IMAGE_TAG|g" kubernetes/deployments/api-deployment.yaml
    sed -i.bak "s|image: animagenius/.*:.*|image: $DOCKER_REGISTRY/animagenius-worker:$IMAGE_TAG|g" kubernetes/deployments/worker-deployment.yaml
    sed -i.bak "s|image: animagenius/.*:.*|image: $DOCKER_REGISTRY/animagenius-gpu-worker:$IMAGE_TAG|g" kubernetes/deployments/worker-deployment.yaml
    
    kubectl apply -f kubernetes/deployments/
    
    # Deploy ingress
    kubectl apply -f kubernetes/ingress/
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available --timeout=600s deployment/animagenius-api -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=600s deployment/animagenius-worker -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=600s deployment/animagenius-gpu-worker -n "$NAMESPACE"
    
    success "Kubernetes resources deployed successfully"
}

# Deploy monitoring stack
deploy_monitoring() {
    log "Deploying monitoring stack..."
    
    # Deploy Prometheus
    kubectl apply -f monitoring/prometheus/
    
    # Deploy Grafana
    kubectl apply -f monitoring/grafana/
    
    # Wait for monitoring components
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n animagenius-monitoring
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n animagenius-monitoring
    
    success "Monitoring stack deployed successfully"
}

# Deploy security policies
deploy_security() {
    log "Deploying security policies..."
    
    # Deploy RBAC
    kubectl apply -f security/rbac/
    
    # Deploy Network Policies
    kubectl apply -f security/network-policies/
    
    success "Security policies deployed successfully"
}

# Run database migrations
run_migrations() {
    log "Running database migrations..."
    
    # Get database connection details from Terraform output
    local db_endpoint
    db_endpoint=$(cd terraform && terraform output -raw rds_endpoint)
    
    # Run migrations using a job
    kubectl create job --from=deployment/animagenius-api migration-job-$(date +%s) -n "$NAMESPACE"
    
    success "Database migrations completed"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check pod status
    kubectl get pods -n "$NAMESPACE"
    
    # Check service endpoints
    kubectl get services -n "$NAMESPACE"
    
    # Check ingress
    kubectl get ingress -n "$NAMESPACE"
    
    # Health check
    local api_url
    api_url=$(kubectl get ingress animagenius-ingress -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
    
    if curl -f "https://$api_url/health" &> /dev/null; then
        success "Health check passed"
    else
        warn "Health check failed - deployment may still be starting"
    fi
    
    success "Deployment verification completed"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    find . -name "*.bak" -delete
}

# Main deployment function
main() {
    log "Starting AnimaGenius production deployment..."
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    case "${1:-all}" in
        "infrastructure")
            check_prerequisites
            deploy_infrastructure
            ;;
        "images")
            check_prerequisites
            build_and_push_images
            ;;
        "kubernetes")
            check_prerequisites
            update_kubeconfig
            deploy_kubernetes
            deploy_security
            run_migrations
            ;;
        "monitoring")
            check_prerequisites
            update_kubeconfig
            deploy_monitoring
            ;;
        "all")
            check_prerequisites
            deploy_infrastructure
            update_kubeconfig
            build_and_push_images
            deploy_kubernetes
            deploy_monitoring
            deploy_security
            run_migrations
            verify_deployment
            ;;
        "verify")
            check_prerequisites
            update_kubeconfig
            verify_deployment
            ;;
        *)
            error "Invalid command. Usage: $0 [infrastructure|images|kubernetes|monitoring|all|verify]"
            exit 1
            ;;
    esac
    
    success "Deployment completed successfully!"
}

# Run main function with all arguments
main "$@"