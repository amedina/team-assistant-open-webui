#!/bin/bash
set -e

cd /opt/openwebui

# Wait for startup script to complete
while [ ! -f /var/log/startup-complete.log ]; do
    echo "Waiting for VM startup to complete..."
    sleep 10
done

# Get repository URL (you'll need to update this)
echo "Please provide your repository URL when prompted, or press Enter to use local file transfer"
read -p "Repository URL (optional): " REPO_URL

if [ ! -z "$REPO_URL" ]; then
    echo "Cloning repository..."
    git clone $REPO_URL temp_repo
    mv temp_repo/* . 2>/dev/null || true
    mv temp_repo/.* . 2>/dev/null || true
    rm -rf temp_repo
else
    echo "Repository URL not provided. Please transfer files manually."
fi

# Create environment file
cat > .env.production << EOF
WEBUI_SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(cat /root/db_credentials.txt 2>/dev/null | grep "Database password:" | cut -d' ' -f3 || echo "CHANGE_ME")
DB_CONNECTION_NAME=$(cat /root/deployment_vars.env 2>/dev/null | grep DB_CONNECTION_NAME | cut -d= -f2 || echo "CHANGE_ME")
ENABLE_SIGNUP=false
ENABLE_LOGIN_FORM=true
GCS_BUCKET_NAME=ps-agent-sandbox-openwebui-storage
ENABLE_MONITORING=true
LOG_LEVEL=INFO
EOF

# Create necessary directories
mkdir -p ssl

# Generate temporary SSL certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/server.key \
    -out ssl/server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create service account key
PROJECT_NUMBER=$(gcloud projects describe ps-agent-sandbox --format="value(projectNumber)")
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud iam service-accounts keys create service-account-key.json \
    --iam-account=${COMPUTE_SA}

echo "VM deployment script completed"
