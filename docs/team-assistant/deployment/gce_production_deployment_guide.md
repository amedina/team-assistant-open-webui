# Open WebUI Production Deployment on Google Compute Engine

## Overview
This guide implements a production-ready Open WebUI deployment on GCP with:
- Compute Engine VM (e2-standard-4)
- Cloud SQL PostgreSQL database
- Cloud Storage for file persistence
- Application Load Balancer with managed SSL
- Cloud Monitoring & Logging
- Automated backups and security hardening

## Prerequisites
- Google Cloud Project: `ps-agent-sandbox`
- gcloud CLI installed and authenticated
- Domain name (optional - we'll use GCP-provided temporarily)
- Basic Docker knowledge (Docker will run on GCE, not locally)
- Git access to your repository (for code deployment)

## Architecture Overview
```
Internet → Load Balancer (SSL) → VM Instance → Open WebUI
                                      ↓
                               Cloud SQL (PostgreSQL)
                                      ↓
                               Cloud Storage (Files/Backups)
```

## Step 1: Environment Setup

### 1.1 Set Project Variables
```bash
# Set your project variables
export PROJECT_ID="ps-agent-sandbox"
export REGION="us-central1"
export ZONE="us-central1-a"
export VM_NAME="openwebui-prod"
export DB_INSTANCE_NAME="openwebui-db"
export BUCKET_NAME="${PROJECT_ID}-openwebui-storage"

# Set project
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
```

### 1.2 Enable Required APIs
```bash
gcloud services enable compute.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable certificatemanager.googleapis.com
```

## Step 2: Database Setup (Cloud SQL)

### 2.1 Create PostgreSQL Instance
```bash
# Create Cloud SQL PostgreSQL instance
gcloud sql instances create $DB_INSTANCE_NAME \
    --database-version=POSTGRES_15 \
    --tier=db-g1-small \
    --region=$REGION \
    --storage-type=SSD \
    --storage-size=20GB \
    --storage-auto-increase \
    --backup-start-time=03:00 \
    --enable-bin-log \
    --maintenance-window-day=SUN \
    --maintenance-window-hour=04 \
    --deletion-protection

# Create database and user
gcloud sql databases create openwebui --instance=$DB_INSTANCE_NAME

# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32)
echo "Database password: $DB_PASSWORD" > db_credentials.txt
chmod 600 db_credentials.txt

# Create database user
gcloud sql users create openwebui \
    --instance=$DB_INSTANCE_NAME \
    --password=$DB_PASSWORD
```

### 2.2 Configure Database Access
```bash
# Get the instance connection name
DB_CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")
echo "DB_CONNECTION_NAME=$DB_CONNECTION_NAME" >> deployment_vars.env
```

## Step 3: Storage Setup

### 3.1 Create Cloud Storage Bucket
```bash
# Create storage bucket for files and backups
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME

# Set bucket permissions
gsutil iam ch serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com:objectAdmin gs://$BUCKET_NAME
```

## Step 4: VM Instance Creation

### 4.1 Create VM with Startup Script
```bash
# Create startup script
cat > startup-script.sh << 'EOF'
#!/bin/bash

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

# Create application directory
mkdir -p /opt/openwebui
cd /opt/openwebui

# Install git for code deployment
apt-get install git -y

# Clone the repository (you'll need to provide the correct URL)
# git clone https://github.com/YOUR_USERNAME/team-assistant-open-webui.git .
# For now, we'll do this manually in later steps

echo "VM setup completed" > /var/log/startup-complete.log
EOF

# Create VM instance
gcloud compute instances create $VM_NAME \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --network-interface=network-tier=PREMIUM,subnet=default \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=${PROJECT_ID}@appspot.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --create-disk=auto-delete=yes,boot=yes,device-name=$VM_NAME,image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts,mode=rw,size=50,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-ssd \
    --metadata-from-file startup-script=startup-script.sh \
    --tags=openwebui-server,http-server,https-server
```

### 4.2 Configure Firewall Rules
```bash
# Create firewall rules
gcloud compute firewall-rules create allow-openwebui-http \
    --allow tcp:80,tcp:8080 \
    --source-ranges 0.0.0.0/0 \
    --target-tags openwebui-server \
    --description="Allow HTTP traffic to Open WebUI"

gcloud compute firewall-rules create allow-openwebui-https \
    --allow tcp:443 \
    --source-ranges 0.0.0.0/0 \
    --target-tags openwebui-server \
    --description="Allow HTTPS traffic to Open WebUI"
```

## Step 5: Application Deployment

### 5.1 Connect to VM and Deploy Application
```bash
# SSH into the VM
gcloud compute ssh $VM_NAME --zone=$ZONE

# Once connected to VM, run these commands:
```

### 5.2 Application Configuration Files

Create the following files on the VM:

**docker-compose.prod.yml**
```yaml
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
```

**nginx.conf**
```nginx
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
        
        # Redirect HTTP to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name _;

        # SSL configuration (will be updated with real certificates)
        ssl_certificate /etc/ssl/certs/server.crt;
        ssl_certificate_key /etc/ssl/certs/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        # Security headers
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

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

**.env.production**
```bash
# Generate these securely
WEBUI_SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=your_db_password_from_earlier
DB_CONNECTION_NAME=your_connection_name_from_earlier
ENABLE_SIGNUP=false
ENABLE_LOGIN_FORM=true

# Google Cloud Storage
GCS_BUCKET_NAME=ps-agent-sandbox-openwebui-storage

# Monitoring
ENABLE_MONITORING=true
LOG_LEVEL=INFO
```

## Step 6: Load Balancer & SSL Setup

### 6.1 Create Load Balancer
```bash
# Create health check
gcloud compute health-checks create http openwebui-health-check \
    --port 80 \
    --request-path /health \
    --check-interval 30s \
    --timeout 10s \
    --healthy-threshold 2 \
    --unhealthy-threshold 3

# Create instance group
gcloud compute instance-groups unmanaged create openwebui-ig \
    --zone=$ZONE

gcloud compute instance-groups unmanaged add-instances openwebui-ig \
    --instances=$VM_NAME \
    --zone=$ZONE

# Create backend service
gcloud compute backend-services create openwebui-backend \
    --protocol HTTP \
    --health-checks openwebui-health-check \
    --global

gcloud compute backend-services add-backend openwebui-backend \
    --instance-group openwebui-ig \
    --instance-group-zone $ZONE \
    --global

# Create URL map
gcloud compute url-maps create openwebui-map \
    --default-service openwebui-backend

# Create SSL certificate (managed)
gcloud compute ssl-certificates create openwebui-ssl \
    --domains=YOUR_DOMAIN_HERE \
    --global

# Create HTTPS proxy
gcloud compute target-https-proxies create openwebui-https-proxy \
    --url-map openwebui-map \
    --ssl-certificates openwebui-ssl

# Create global forwarding rule
gcloud compute forwarding-rules create openwebui-https-rule \
    --global \
    --target-https-proxy openwebui-https-proxy \
    --ports 443

# Get the load balancer IP
LB_IP=$(gcloud compute forwarding-rules describe openwebui-https-rule --global --format="value(IPAddress)")
echo "Load Balancer IP: $LB_IP"
```

## Step 7: Monitoring & Logging Setup

### 7.1 Create Monitoring Dashboard
```bash
# Create custom monitoring dashboard
cat > monitoring-dashboard.json << EOF
{
  "displayName": "Open WebUI Production Dashboard",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "VM CPU Utilization",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"gce_instance\" AND resource.label.instance_name=\"${VM_NAME}\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_MEAN"
                  }
                },
                "unitOverride": "percent"
              }
            }]
          }
        }
      }
    ]
  }
}
EOF

# Create the dashboard
gcloud alpha monitoring dashboards create --config-from-file=monitoring-dashboard.json
```

### 7.2 Set Up Alerting
```bash
# Create notification channel (email)
gcloud alpha monitoring channels create \
    --display-name="OpenWebUI Admin" \
    --type=email \
    --channel-labels=email_address=YOUR_EMAIL@example.com

# Create alerting policy for high CPU
cat > cpu-alert-policy.yaml << EOF
displayName: "OpenWebUI High CPU Usage"
conditions:
  - displayName: "CPU usage above 80%"
    conditionThreshold:
      filter: 'resource.type="gce_instance" AND resource.label.instance_name="${VM_NAME}"'
      comparison: COMPARISON_GREATER_THAN
      thresholdValue: 0.8
      duration: 300s
      aggregations:
        - alignmentPeriod: 60s
          perSeriesAligner: ALIGN_MEAN
combiner: OR
enabled: true
EOF

gcloud alpha monitoring policies create --policy-from-file=cpu-alert-policy.yaml
```

## Step 8: Backup & Disaster Recovery

### 8.1 Automated Backup Script
```bash
# Create backup script on VM
cat > /opt/openwebui/backup.sh << 'EOF'
#!/bin/bash

# Backup script for Open WebUI
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/openwebui_backup_$DATE"
BUCKET="gs://ps-agent-sandbox-openwebui-storage/backups"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
gcloud sql export sql openwebui-db $BUCKET/db_backup_$DATE.sql

# Backup application data
docker exec openwebui tar czf /tmp/app_data_$DATE.tar.gz /app/backend/data
docker cp openwebui:/tmp/app_data_$DATE.tar.gz $BACKUP_DIR/

# Upload to Cloud Storage
gsutil -m cp -r $BACKUP_DIR/* $BUCKET/

# Cleanup local backups older than 7 days
find /tmp -name "openwebui_backup_*" -type d -mtime +7 -exec rm -rf {} \;

# Cleanup cloud backups older than 30 days
gsutil -m rm $BUCKET/$(date -d '30 days ago' +%Y%m%d)_*

echo "Backup completed: $DATE"
EOF

chmod +x /opt/openwebui/backup.sh

# Schedule daily backups
echo "0 2 * * * /opt/openwebui/backup.sh" | crontab -
```

## Step 9: Security Hardening

### 9.1 VM Security Configuration
```bash
# SSH into VM and run:

# Update system packages
sudo apt update && sudo apt upgrade -y

# Configure automatic security updates
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades

# Install fail2ban
sudo apt install fail2ban -y

# Configure firewall (ufw)
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp

# Harden SSH
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

## Step 10: Deployment Commands

### 10.1 Final Deployment Steps

**Step A: Deploy Code to VM (Since Docker can't run locally)**
```bash
# SSH into the VM first
gcloud compute ssh $VM_NAME --zone=$ZONE

# On the VM - Clone your repository
cd /opt/openwebui

# Option 1: Clone from Git (recommended)
# Replace with your actual repository URL
git clone https://github.com/YOUR_USERNAME/team-assistant-open-webui.git temp_repo
mv temp_repo/* .
mv temp_repo/.* . 2>/dev/null || true
rm -rf temp_repo

# Option 2: If using private repo, you may need to set up SSH keys or access tokens
# git clone git@github.com:YOUR_USERNAME/team-assistant-open-webui.git temp_repo

# Verify files are present
ls -la
```

**Step B: Configure Environment and Deploy**
```bash
# Still on the VM:
cd /opt/openwebui

# Create the environment file with actual values
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

# Load environment variables
source .env.production

# Create necessary directories
mkdir -p ssl

# Generate temporary self-signed SSL certificates (will be replaced by load balancer)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/server.key \
    -out ssl/server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create service account key for Cloud SQL proxy
# (This should be created via IAM, but for simplicity we'll use default service account)
gcloud iam service-accounts keys create service-account-key.json \
    --iam-account=${PROJECT_ID}@appspot.gserviceaccount.com

# Build and start the application
docker-compose -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f openwebui
```

**Step C: Alternative File Transfer Method (if Git not available)**
```bash
# From your local machine (if you need to transfer files manually):

# Create a temporary directory and zip your code
tar -czf openwebui-code.tar.gz --exclude='.git' --exclude='node_modules' --exclude='__pycache__' .

# Transfer to VM
gcloud compute scp openwebui-code.tar.gz $VM_NAME:/tmp/ --zone=$ZONE

# SSH into VM and extract
gcloud compute ssh $VM_NAME --zone=$ZONE

# On VM:
cd /opt/openwebui
tar -xzf /tmp/openwebui-code.tar.gz
rm /tmp/openwebui-code.tar.gz

# Continue with Step B above
```

## Step 11: Testing & Validation

### 11.1 Health Checks
```bash
# Test application health
curl -k https://YOUR_DOMAIN/health

# Check database connectivity
docker exec openwebui python -c "import psycopg2; print('DB connection OK')"

# Verify monitoring
gcloud logging read "resource.type=gce_instance AND resource.labels.instance_name=$VM_NAME" --limit=10
```

## Maintenance Procedures

### Daily Tasks
- Check application logs
- Monitor resource usage
- Verify backup completion

### Weekly Tasks
- Review security logs
- Update application dependencies
- Check SSL certificate status

### Monthly Tasks
- Apply system updates
- Review and rotate secrets
- Performance optimization review

## Troubleshooting Common Issues

### Application Won't Start
```bash
# Check Docker logs
docker-compose -f docker-compose.prod.yml logs

# Check database connectivity
docker exec cloud-sql-proxy /cloud_sql_proxy -instances=$DB_CONNECTION_NAME=tcp:localhost:5432 -credential_file=/config/key.json
```

### SSL Certificate Issues
```bash
# Check certificate status
gcloud compute ssl-certificates describe openwebui-ssl --global

# Force certificate renewal
gcloud compute ssl-certificates create openwebui-ssl-v2 --domains=YOUR_DOMAIN --global
```

### High Resource Usage
```bash
# Monitor resources
docker stats
htop

# Scale database if needed
gcloud sql instances patch $DB_INSTANCE_NAME --tier=db-g1-small
```

## Cost Optimization Tips

1. **Right-size VM**: Monitor usage and downsize if possible
2. **Scheduled start/stop**: For non-24/7 usage
3. **Preemptible instances**: For development environments
4. **Storage lifecycle**: Automatic deletion of old backups
5. **Load balancer optimization**: Use regional instead of global if possible

## Next Steps

1. **Domain Configuration**: Update DNS records to point to Load Balancer IP
2. **SSL Certificate**: Update certificate with your actual domain
3. **Monitoring Setup**: Configure alerting for your email
4. **User Management**: Set up initial admin accounts
5. **Backup Testing**: Perform restore test

This completes your production-ready Open WebUI deployment on Google Compute Engine! 