#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <environment> [options]"
    echo ""
    echo "Environments:"
    echo "  staging   - Staging environment (auto-deploy on 'main' branch push)"
    echo "  prod      - Production environment (manual deploy via version tags)"
    echo ""
    echo "Options:"
    echo "  --init    - Run terraform init"
    echo "  --plan    - Run terraform plan only"
    echo "  --apply   - Run terraform apply (default)"
    echo "  --destroy - Run terraform destroy"
    echo "  --auto-approve - Auto approve apply/destroy"
    echo ""
    echo "Development Workflow:"
    echo "  • Local development: Run Open WebUI locally for development"
    echo "  • Staging deployment: Push to 'main' branch for automatic staging deployment"
    echo "  • Production deployment: Create version tag (v1.0.0) for manual production deployment"
    echo ""
    echo "Examples:"
    echo "  $0 staging --init"
    echo "  $0 staging --plan"
    echo "  $0 prod --apply"
    echo "  $0 staging --destroy --auto-approve"
}

# Parse arguments
ENVIRONMENT=""
ACTION="apply"
AUTO_APPROVE=""
RUN_INIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        staging|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        --init)
            RUN_INIT=true
            shift
            ;;
        --plan)
            ACTION="plan"
            shift
            ;;
        --apply)
            ACTION="apply"
            shift
            ;;
        --destroy)
            ACTION="destroy"
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE="-auto-approve"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
    print_error "Environment is required"
    show_usage
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_error "Valid environments: staging, prod"
    print_error ""
    print_error "Note: Development happens locally. Use 'staging' for testing and 'prod' for production."
    show_usage
    exit 1
fi

# Set working directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environments/$ENVIRONMENT"

if [[ ! -d "$ENV_DIR" ]]; then
    print_error "Environment directory not found: $ENV_DIR"
    exit 1
fi

print_status "Deploying to $ENVIRONMENT environment"
print_status "Working directory: $ENV_DIR"

cd "$ENV_DIR"

# Check prerequisites
print_status "Checking prerequisites..."

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi

# Check if terraform.tfvars exists
if [[ ! -f "terraform.tfvars" ]]; then
    print_error "terraform.tfvars not found in $ENV_DIR"
    print_status "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values"
    exit 1
fi

# Validate gcloud authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    print_error "No active gcloud authentication found"
    print_status "Please run: gcloud auth login"
    exit 1
fi

# Get project ID from terraform.tfvars
PROJECT_ID=$(grep '^project_id' terraform.tfvars | cut -d'"' -f2)
if [[ -z "$PROJECT_ID" ]]; then
    print_error "Could not extract project_id from terraform.tfvars"
    exit 1
fi

print_status "Using project: $PROJECT_ID"

# Set the gcloud project
gcloud config set project "$PROJECT_ID" > /dev/null 2>&1

# Initialize Terraform if requested
if [[ "$RUN_INIT" == true ]]; then
    print_status "Initializing Terraform..."
    terraform init
    print_success "Terraform initialized"
fi

# Run the specified action
case $ACTION in
    plan)
        print_status "Running Terraform plan..."
        terraform plan
        ;;
    apply)
        print_status "Running Terraform apply..."
        if [[ "$ENVIRONMENT" == "prod" && -z "$AUTO_APPROVE" ]]; then
            print_warning "Production deployment requires manual approval"
            terraform apply
        else
            terraform apply $AUTO_APPROVE
        fi
        if [[ $? -eq 0 ]]; then
            print_success "Deployment completed successfully!"
            print_status "Getting deployment outputs..."
            terraform output
        fi
        ;;
    destroy)
        if [[ "$ENVIRONMENT" == "prod" ]]; then
            print_warning "You are about to destroy PRODUCTION infrastructure!"
            read -p "Are you absolutely sure? Type 'destroy-prod' to confirm: " confirmation
            if [[ "$confirmation" != "destroy-prod" ]]; then
                print_status "Destruction cancelled"
                exit 0
            fi
        fi
        print_status "Running Terraform destroy..."
        terraform destroy $AUTO_APPROVE
        if [[ $? -eq 0 ]]; then
            print_success "Infrastructure destroyed successfully"
        fi
        ;;
esac

print_success "Operation completed for $ENVIRONMENT environment" 