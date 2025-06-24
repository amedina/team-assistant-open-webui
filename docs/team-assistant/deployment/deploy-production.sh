#!/bin/bash

# Open WebUI FULLY AUTOMATED Production Deployment Script
# This script handles everything automatically with proper error handling and retries

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
PROJECT_ID="ps-agent-sandbox"
REGION="us-central1"
ZONE="us-central1-a"
VM_NAME="openwebui-prod"
DB_INSTANCE_NAME="openwebui-db"
BUCKET_NAME="${PROJECT_ID}-openwebui-storage"

print_step "🚀 Starting FULLY AUTOMATED Open WebUI Production Deployment"
print_status "Project: $PROJECT_ID | Region: $REGION | VM: $VM_NAME"

# Utility function for retrying commands
retry_command() {
    local cmd="$1"
    local description="$2"
    local max_attempts=5
    local delay=10
    
    for i in $(seq 1 $max_attempts); do
        print_status "Attempt $i/$max_attempts: $description"
        if eval "$cmd"; then
            print_status "✅ Success: $description"
            return 0
        else
            if [ $i -eq $max_attempts ]; then
                print_error "❌ Failed after $max_attempts attempts: $description"
                return 1
            fi
            print_warning "⏳ Attempt $i failed, retrying in ${delay}s..."
            sleep $delay
        fi
    done
}

# Function to wait for VM to be SSH ready
wait_for_ssh() {
    local vm_name="$1"
    local zone="$2"
    local max_wait=300  # 5 minutes
    local wait_time=0
    
    print_status "⏳ Waiting for VM to be SSH ready..."
    
    while [ $wait_time -lt $max_wait ]; do
        if gcloud compute ssh $vm_name --zone=$zone --command="echo 'SSH Ready'" --quiet &>/dev/null; then
            print_status "✅ VM is SSH ready!"
            return 0
        fi
        
        echo -n "."
        sleep 10
        wait_time=$((wait_time + 10))
    done
    
    print_error "❌ VM not ready for SSH after ${max_wait}s"
    return 1
}

# Function to wait for startup script completion
wait_for_startup_completion() {
    local vm_name="$1"
    local zone="$2"
    
    print_status "⏳ Waiting for VM startup script to complete..."
    
    while true; do
        if gcloud compute ssh $vm_name --zone=$zone --command="[ -f /var/log/startup-complete.log ]" --quiet 2>/dev/null; then
            print_status "✅ VM startup script completed!"
            return 0
        fi
        
        echo -n "."
        sleep 15
    done
}

# Check prerequisites
check_prerequisites() {
    print_step "🔍 Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed"
        exit 1
    fi
    
    if ! command -v gsutil &> /dev/null; then
        print_error "gsutil is not installed"
        exit 1
    fi
    
    # Set project configuration
    gcloud config set project $PROJECT_ID --quiet
    gcloud config set compute/region $REGION --quiet
    gcloud config set compute/zone $ZONE --quiet
    
    print_status "✅ Prerequisites check passed"
}

# Enable APIs with retry
enable_apis() {
    print_step "🔧 Enabling Google Cloud APIs..."
    
    local apis=(
        "compute.googleapis.com"
        "sqladmin.googleapis.com" 
        "storage-api.googleapis.com"
        "monitoring.googleapis.com"
        "logging.googleapis.com"
        "certificatemanager.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        retry_command "gcloud services enable $api --quiet" "Enabling $api"
    done
    
    print_status "✅ All APIs enabled"
}

# Create database with proper logic
create_database() {
    print_step "🗄️  Setting up Cloud SQL PostgreSQL..."
    
    if gcloud sql instances describe $DB_INSTANCE_NAME --quiet &>/dev/null; then
        print_warning "Database instance already exists"
        
        # Get existing connection info
        DB_CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")
        echo "DB_CONNECTION_NAME=$DB_CONNECTION_NAME" > deployment_vars.env
        
        if [ -f "db_credentials.txt" ]; then
            print_status "✅ Using existing database credentials"
        else
            print_error "Database exists but credentials missing. Creating new user..."
            DB_PASSWORD=$(openssl rand -base64 32)
            echo "Database password: $DB_PASSWORD" > db_credentials.txt
            chmod 600 db_credentials.txt
        fi
    else
        print_status "Creating new Cloud SQL instance..."
        
        gcloud sql instances create $DB_INSTANCE_NAME \
            --database-version=POSTGRES_15 \
            --tier=db-g1-small \
            --region=$REGION \
            --storage-type=SSD \
            --storage-size=20GB \
            --storage-auto-increase \
            --backup-start-time=03:00 \
            --maintenance-window-day=SUN \
            --maintenance-window-hour=04 \
            --deletion-protection \
            --quiet
        
        print_status "✅ Database instance created"
        
        # Create database and user
        gcloud sql databases create openwebui --instance=$DB_INSTANCE_NAME --quiet
        
        DB_PASSWORD=$(openssl rand -base64 32)
        echo "Database password: $DB_PASSWORD" > db_credentials.txt
        chmod 600 db_credentials.txt
        
        gcloud sql users create openwebui \
            --instance=$DB_INSTANCE_NAME \
            --password=$DB_PASSWORD \
            --quiet
        
        DB_CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")
        echo "DB_CONNECTION_NAME=$DB_CONNECTION_NAME" > deployment_vars.env
        
        print_status "✅ Database and user created"
    fi
}

# Create storage bucket
create_storage() {
    print_step "🪣 Setting up Cloud Storage..."
    
    if gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
        print_warning "Storage bucket already exists"
    else
        gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME
        
        # Get correct service account
        PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
        COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
        
        gsutil iam ch serviceAccount:${COMPUTE_SA}:objectAdmin gs://$BUCKET_NAME
        print_status "✅ Storage bucket created"
    fi
}

# Create VM with proper startup script
create_vm() {
    print_step "🖥️  Creating VM instance..."
    
    if gcloud compute instances describe $VM_NAME --zone=$ZONE --quiet &>/dev/null; then
        print_warning "VM instance already exists"
        return 0
    fi
    
    # Get correct service account
    PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
    COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    
    # Create enhanced startup script
    cat > startup-script.sh << 'EOF'
#!/bin/bash
exec > >(tee /var/log/startup-script.log) 2>&1

echo "Starting VM setup at $(date)"

# Update system
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Cloud SQL Proxy
curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
chmod +x cloud_sql_proxy
mv cloud_sql_proxy /usr/local/bin/

# Install monitoring agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# Install additional tools
apt-get install -y git curl wget unzip htop

# Create application directory
mkdir -p /opt/openwebui
chmod 755 /opt/openwebui

# Signal completion
echo "VM setup completed at $(date)" > /var/log/startup-complete.log
echo "Setup completed successfully"
EOF

    # Create VM
    gcloud compute instances create $VM_NAME \
        --zone=$ZONE \
        --machine-type=e2-standard-4 \
        --network-interface=network-tier=PREMIUM,subnet=default \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --service-account=${COMPUTE_SA} \
        --scopes=https://www.googleapis.com/auth/cloud-platform \
        --create-disk=auto-delete=yes,boot=yes,device-name=$VM_NAME,image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts,mode=rw,size=50,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-ssd \
        --metadata-from-file startup-script=startup-script.sh \
        --tags=openwebui-server,http-server,https-server \
        --quiet
    
    print_status "✅ VM instance created"
    
    # Create firewall rules
    gcloud compute firewall-rules create allow-openwebui-http \
        --allow tcp:80,tcp:8080 \
        --source-ranges 0.0.0.0/0 \
        --target-tags openwebui-server \
        --description="Allow HTTP traffic to Open WebUI" \
        --quiet 2>/dev/null || true
    
    gcloud compute firewall-rules create allow-openwebui-https \
        --allow tcp:443 \
        --source-ranges 0.0.0.0/0 \
        --target-tags openwebui-server \
        --description="Allow HTTPS traffic to Open WebUI" \
        --quiet 2>/dev/null || true
    
    print_status "✅ Firewall rules configured"
}

# Create configuration files
create_config_files() {
    print_step "📁 Creating configuration files..."
    
    # Docker Compose with environment variable substitution
    cat > docker-compose.prod.yml << 'EOF'
version: '3.8'

services:
  openwebui:
    build: .
    container_name: openwebui
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
      - DATABASE_URL=postgresql://openwebui:${DB_PASSWORD}@localhost:5432/openwebui
      - DATA_DIR=/app/backend/data
      - ENABLE_SIGNUP=false
      - ENABLE_LOGIN_FORM=true
    volumes:
      - openwebui-data:/app/backend/data
      - /tmp/cloudsql:/cloudsql
    depends_on:
      - cloud-sql-proxy
    networks:
      - openwebui-network

  cloud-sql-proxy:
    image: gcr.io/cloudsql-docker/gce-proxy:1.33.2
    container_name: cloud-sql-proxy
    restart: unless-stopped
    command: /cloud_sql_proxy -instances=${DB_CONNECTION_NAME}=tcp:0.0.0.0:5432 -credential_file=/config/key.json
    volumes:
      - /opt/openwebui/service-account-key.json:/config/key.json
      - /tmp/cloudsql:/cloudsql
    networks:
      - openwebui-network

  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/ssl/certs
    depends_on:
      - openwebui
    networks:
      - openwebui-network

volumes:
  openwebui-data:

networks:
  openwebui-network:
    driver: bridge
EOF

    # Nginx configuration
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream openwebui {
        server openwebui:8080;
    }

    server {
        listen 80;
        server_name _;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name _;

        ssl_certificate /etc/ssl/certs/server.crt;
        ssl_certificate_key /etc/ssl/certs/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

        client_max_body_size 100M;

        location / {
            proxy_pass http://openwebui;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_cache_bypass $http_upgrade;
            proxy_buffering off;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

    # Create VM deployment script
    cat > vm-complete-setup.sh << 'VMEOF'
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
VMEOF

    print_status "✅ Configuration files created"
}

# Deploy to VM with full automation
deploy_to_vm() {
    print_step "📤 Deploying to VM (fully automated)..."
    
    # Wait for VM to be SSH ready
    wait_for_ssh $VM_NAME $ZONE
    
    # Wait for startup script to complete
    wait_for_startup_completion $VM_NAME $ZONE
    
    # Copy all files to VM with retry
    print_status "📁 Copying deployment files..."
    retry_command "gcloud compute scp docker-compose.prod.yml nginx.conf vm-complete-setup.sh $VM_NAME:/tmp/ --zone=$ZONE --quiet" "Copying config files"
    retry_command "gcloud compute scp db_credentials.txt deployment_vars.env $VM_NAME:/tmp/ --zone=$ZONE --quiet" "Copying credentials"
    
    # Set up VM with application configuration
    print_status "⚙️ Configuring VM application environment..."
    gcloud compute ssh $VM_NAME --zone=$ZONE --command="
        sudo cp /tmp/db_credentials.txt /tmp/deployment_vars.env /root/ &&
        sudo cp /tmp/docker-compose.prod.yml /tmp/nginx.conf /opt/openwebui/ &&
        sudo cp /tmp/vm-complete-setup.sh /opt/openwebui/ &&
        sudo chmod +x /opt/openwebui/vm-complete-setup.sh &&
        sudo /opt/openwebui/vm-complete-setup.sh
    " --quiet
    
    print_status "✅ VM fully configured and ready!"
}

# Show final deployment status
show_completion_status() {
    print_step "🎉 Deployment Complete!"
    
    # Get VM IP
    VM_IP=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    
    echo
    print_status "🌐 Your Open WebUI infrastructure is ready!"
    print_status "📍 VM External IP: $VM_IP"
    print_status "🔗 Temporary Access: http://$VM_IP:8080 (once app is deployed)"
    print_status "📁 Application Directory: /opt/openwebui"
    
    echo
    print_step "🚀 FINAL STEPS - Deploy Your Application:"
    echo "1. SSH into VM: gcloud compute ssh $VM_NAME --zone=$ZONE"
    echo "2. Navigate to app dir: cd /opt/openwebui" 
    echo "3. Deploy your code:"
    echo "   Option A (Git): git clone YOUR_REPO_URL ."
    echo "   Option B (Transfer): Use 'gcloud compute scp' to transfer files"
    echo "4. Start application: sudo docker-compose -f docker-compose.prod.yml up -d"
    echo "5. Check status: sudo docker-compose -f docker-compose.prod.yml ps"
    echo
    print_status "💾 Credentials saved in: db_credentials.txt"
    print_status "⚙️ All config files ready in VM"
    
    echo
    print_step "🎯 Next time: Just deploy your code and run 'docker-compose up -d'!"
}

# Main execution with full error handling
main() {
    print_step "🏁 Starting FULLY AUTOMATED deployment..."
    
    # Run all deployment steps
    check_prerequisites
    enable_apis  
    create_database
    create_storage
    create_vm
    create_config_files
    deploy_to_vm
    show_completion_status
    
    print_step "✅ FULLY AUTOMATED DEPLOYMENT COMPLETED SUCCESSFULLY!"
    print_status "🎉 Zero manual steps required!"
}

# Run with error handling
if ! main "$@"; then
    print_error "❌ Deployment failed. Check the logs above."
    exit 1
fi 