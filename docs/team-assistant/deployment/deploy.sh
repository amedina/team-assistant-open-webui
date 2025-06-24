#!/bin/bash

# Open WebUI Production Deployment Script for GCP
# This script handles the entire deployment process when Docker cannot run locally

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Configuration
PROJECT_ID="ps-agent-sandbox"
REGION="us-central1"
ZONE="us-central1-a"
VM_NAME="openwebui-prod"
DB_INSTANCE_NAME="openwebui-db"
BUCKET_NAME="${PROJECT_ID}-openwebui-storage"

print_status "Starting Open WebUI Production Deployment"
print_status "Project: $PROJECT_ID"
print_status "Region: $REGION"
print_status "VM Name: $VM_NAME"

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Set project configuration
print_status "Setting up gcloud configuration..."
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Function to enable APIs
enable_apis() {
    print_status "Enabling required Google Cloud APIs..."
    gcloud services enable compute.googleapis.com
    gcloud services enable sqladmin.googleapis.com
    gcloud services enable storage-api.googleapis.com
    gcloud services enable monitoring.googleapis.com
    gcloud services enable logging.googleapis.com
    gcloud services enable certificatemanager.googleapis.com
    print_status "APIs enabled successfully"
}

# Function to create database
create_database() {
    print_status "Creating Cloud SQL PostgreSQL instance..."
    
    # Check if instance already exists
    if gcloud sql instances describe $DB_INSTANCE_NAME &> /dev/null; then
        print_warning "Database instance $DB_INSTANCE_NAME already exists, skipping creation"
        
        # Get existing connection name
        DB_CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")
        echo "DB_CONNECTION_NAME=$DB_CONNECTION_NAME" > deployment_vars.env
        
        # Check if credentials file exists, if not we need to handle this case
        if [ -f "db_credentials.txt" ]; then
            print_status "Using existing database credentials"
        else
            print_error "Database instance exists but credentials file not found!"
            print_error "Please check existing database password manually or reset it"
            print_error "You can find the database user 'openwebui' in the Cloud SQL console"
            exit 1
        fi
        
    else
        # Create new instance
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
            --deletion-protection
        
        print_status "Database instance created successfully"
        
        # Create database
        gcloud sql databases create openwebui --instance=$DB_INSTANCE_NAME
        
        # Generate and store database password
        DB_PASSWORD=$(openssl rand -base64 32)
        echo "Database password: $DB_PASSWORD" > db_credentials.txt
        chmod 600 db_credentials.txt
        
        # Create database user
        gcloud sql users create openwebui \
            --instance=$DB_INSTANCE_NAME \
            --password=$DB_PASSWORD
        
        # Get connection name
        DB_CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")
        echo "DB_CONNECTION_NAME=$DB_CONNECTION_NAME" > deployment_vars.env
        
        print_status "New database setup completed"
    fi
    
    print_status "Database setup completed"
}

# Function to create storage bucket
create_storage() {
    print_status "Creating Cloud Storage bucket..."
    
    # Check if bucket already exists
    if gsutil ls -b gs://$BUCKET_NAME &> /dev/null; then
        print_warning "Bucket $BUCKET_NAME already exists, skipping creation"
    else
        gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME
        # Get the correct Compute Engine service account
        PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
        COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
        gsutil iam ch serviceAccount:${COMPUTE_SA}:objectAdmin gs://$BUCKET_NAME
        print_status "Storage bucket created successfully"
    fi
}

# Function to create VM instance
create_vm() {
    print_status "Creating VM instance..."
    
    # Create startup script
    cat > startup-script.sh << 'EOF'
#!/bin/bash
apt-get update && apt-get upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
chmod +x cloud_sql_proxy
mv cloud_sql_proxy /usr/local/bin/
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install
apt-get install git -y
mkdir -p /opt/openwebui
echo "VM setup completed" > /var/log/startup-complete.log
EOF
    
    # Check if VM already exists
    if gcloud compute instances describe $VM_NAME --zone=$ZONE &> /dev/null; then
        print_warning "VM instance $VM_NAME already exists, skipping creation"
    else
        # Get the correct Compute Engine service account
        PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
        COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
        
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
            --tags=openwebui-server,http-server,https-server
        
        print_status "VM instance created successfully"
    fi
    
    # Create firewall rules
    gcloud compute firewall-rules create allow-openwebui-http \
        --allow tcp:80,tcp:8080 \
        --source-ranges 0.0.0.0/0 \
        --target-tags openwebui-server \
        --description="Allow HTTP traffic to Open WebUI" || true
    
    gcloud compute firewall-rules create allow-openwebui-https \
        --allow tcp:443 \
        --source-ranges 0.0.0.0/0 \
        --target-tags openwebui-server \
        --description="Allow HTTPS traffic to Open WebUI" || true
    
    print_status "Firewall rules configured"
}

# Function to deploy application
deploy_application() {
    print_status "Deploying application to VM..."
    
    # Wait for VM to be ready
    print_status "Waiting for VM to be ready..."
    sleep 60
    
    # Create deployment script to run on VM
    cat > vm-deploy-script.sh << 'VMEOF'
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
VMEOF

    # Copy deployment script to VM
    gcloud compute scp vm-deploy-script.sh $VM_NAME:/tmp/ --zone=$ZONE
    
    # Copy credentials to VM
    gcloud compute scp db_credentials.txt deployment_vars.env $VM_NAME:/root/ --zone=$ZONE
    
    print_status "Files copied to VM. Now you need to complete the deployment manually."
    print_status "Run the following commands:"
    print_status "1. gcloud compute ssh $VM_NAME --zone=$ZONE"
    print_status "2. sudo bash /tmp/vm-deploy-script.sh"
    print_status "3. cd /opt/openwebui && sudo docker-compose -f docker-compose.prod.yml up -d"
}

# Function to create configuration files
create_config_files() {
    print_status "Creating configuration files..."
    
    # Create docker-compose file
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
      - ENABLE_SIGNUP=${ENABLE_SIGNUP:-false}
      - ENABLE_LOGIN_FORM=${ENABLE_LOGIN_FORM:-true}
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

    # Create nginx config
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

    print_status "Configuration files created"
}

# Function to show next steps
show_next_steps() {
    print_status "Deployment infrastructure setup completed!"
    print_status ""
    print_status "Next steps:"
    print_status "1. SSH into your VM: gcloud compute ssh $VM_NAME --zone=$ZONE"
    print_status "2. Navigate to the application directory: cd /opt/openwebui"
    print_status "3. Transfer your application code (via git clone or file transfer)"
    print_status "4. Run: sudo docker-compose -f docker-compose.prod.yml up -d"
    print_status "5. Check status: sudo docker-compose -f docker-compose.prod.yml ps"
    print_status ""
    print_status "Your VM external IP address:"
    gcloud compute instances describe $VM_NAME --zone=$ZONE --format="value(networkInterfaces[0].accessConfigs[0].natIP)"
    print_status ""
    print_status "Database credentials saved in: db_credentials.txt"
    print_status "Configuration files created in current directory"
}

# Main execution
main() {
    print_status "Starting deployment process..."
    
    enable_apis
    create_database
    create_storage
    create_vm
    create_config_files
    
    print_status "Waiting for VM to be ready before deploying application..."
    sleep 30
    
    deploy_application
    show_next_steps
    
    print_status "Deployment script completed successfully!"
}

# Run main function
main "$@" 