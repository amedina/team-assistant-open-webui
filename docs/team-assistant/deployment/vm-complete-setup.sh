#!/bin/bash
set -e

echo "🚀 Starting VM application deployment..."

cd /opt/openwebui

# Create environment file with actual values
echo "📝 Creating environment configuration..."
cat > .env.production << EOF
WEBUI_SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(cat /root/db_credentials.txt | grep "Database password:" | cut -d' ' -f3)
DB_CONNECTION_NAME=$(cat /root/deployment_vars.env | grep DB_CONNECTION_NAME | cut -d= -f2)
ENABLE_SIGNUP=false
ENABLE_LOGIN_FORM=true
GCS_BUCKET_NAME=ps-agent-sandbox-openwebui-storage
ENABLE_MONITORING=true
LOG_LEVEL=INFO
EOF

# Create directories
mkdir -p ssl logs backups

# Generate temporary SSL certificates
echo "🔐 Generating SSL certificates..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/server.key \
    -out ssl/server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null

# Create service account key
echo "🔑 Setting up service account..."
PROJECT_NUMBER=$(gcloud projects describe ps-agent-sandbox --format="value(projectNumber)")
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud iam service-accounts keys create service-account-key.json \
    --iam-account=${COMPUTE_SA} --quiet

echo "✅ VM application setup completed!"
echo "🎯 Ready for application code deployment"
