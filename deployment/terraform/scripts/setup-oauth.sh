#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

show_usage() {
    echo "OAuth Setup Helper for Open WebUI"
    echo ""
    echo "This script helps you set up Google OAuth for your Open WebUI deployment."
    echo ""
    echo "Usage: $0 <project-id> [environment]"
    echo ""
    echo "Arguments:"
    echo "  project-id    - Your Google Cloud Project ID"
    echo "  environment   - Target environment (dev, staging, prod) - optional"
    echo ""
    echo "Examples:"
    echo "  $0 my-gcp-project dev"
    echo "  $0 my-gcp-project"
}

# Parse arguments
PROJECT_ID="$1"
ENVIRONMENT="$2"

if [[ -z "$PROJECT_ID" ]]; then
    print_error "Project ID is required"
    show_usage
    exit 1
fi

print_status "Setting up OAuth for project: $PROJECT_ID"

# Set the gcloud project
gcloud config set project "$PROJECT_ID"

print_status "Enabling required APIs..."
gcloud services enable oauth2.googleapis.com
gcloud services enable iap.googleapis.com

print_status "OAuth setup steps:"
echo ""
echo "1. Go to Google Cloud Console:"
echo "   https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
echo ""
echo "2. Click 'Create Credentials' → 'OAuth 2.0 Client IDs'"
echo ""
echo "3. If prompted, configure the OAuth consent screen:"
echo "   - Choose 'External' user type"
echo "   - Fill in required fields:"
echo "     * App name: Open WebUI"
echo "     * User support email: your-email@domain.com"
echo "     * Developer contact information: your-email@domain.com"
echo ""
echo "4. For the OAuth Client ID:"
echo "   - Application type: Web application"
echo "   - Name: Open WebUI OAuth Client"
echo ""

if [[ -n "$ENVIRONMENT" ]]; then
    print_status "Getting Cloud Run service URL for $ENVIRONMENT..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ENV_DIR="$(dirname "$SCRIPT_DIR")/environments/$ENVIRONMENT"
    
    if [[ -d "$ENV_DIR" ]]; then
        cd "$ENV_DIR"
        if [[ -f "terraform.tfstate" ]]; then
            SERVICE_URL=$(terraform output -raw cloud_run_service_url 2>/dev/null || echo "")
            if [[ -n "$SERVICE_URL" ]]; then
                print_success "Found deployed service URL: $SERVICE_URL"
                echo "5. Add these Authorized redirect URIs:"
                echo "   - $SERVICE_URL/oauth/google/callback"
                echo ""
            fi
        fi
    fi
fi

if [[ -z "$SERVICE_URL" ]]; then
    echo "5. Add Authorized redirect URIs (after deployment):"
    echo "   - https://your-cloud-run-url/oauth/google/callback"
    echo "   - https://your-custom-domain.com/oauth/google/callback (if using custom domain)"
    echo ""
fi

echo "6. Click 'Create' and note down:"
echo "   - Client ID (ends with .apps.googleusercontent.com)"
echo "   - Client Secret"
echo ""
echo "7. Update your terraform.tfvars file with these values:"
echo "   google_oauth_client_id     = \"your-client-id.apps.googleusercontent.com\""
echo "   google_oauth_client_secret = \"your-client-secret\""
echo ""

print_warning "Important Security Notes:"
echo "- Never commit terraform.tfvars with secrets to version control"
echo "- Use environment variables or secret management for production"
echo "- Regularly rotate OAuth client secrets"
echo ""

print_status "OAuth consent screen configuration:"
echo "- App domain: your-domain.com (optional)"
echo "- Privacy policy: https://your-domain.com/privacy (optional)"
echo "- Terms of service: https://your-domain.com/terms (optional)"
echo ""

print_success "OAuth setup instructions complete!"
print_status "After configuring OAuth, run your deployment with:"
echo "  ./scripts/deploy.sh $ENVIRONMENT --apply" 