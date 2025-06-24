# Open WebUI Production Deployment - Quick Start

## Overview

This guide helps you deploy Open WebUI to Google Compute Engine when you **cannot run Docker locally** due to corporate restrictions. All Docker operations will happen on the cloud VM.

## Before You Start

### Prerequisites
- ✅ Google Cloud Project: `ps-agent-sandbox`
- ✅ gcloud CLI installed and authenticated locally
- ✅ Basic familiarity with SSH and command line
- ✅ No Docker required locally (runs on GCE VM)

### Cost Estimate
- **VM Instance (e2-standard-4)**: ~$120/month
- **Cloud SQL (db-g1-small)**: ~$25/month
- **Cloud Storage**: ~$5/month
- **Load Balancer**: ~$18/month
- **Total**: ~$168/month

## Quick Start (3 Options)

### Option 1: Automated Deployment Script (Recommended)

**Step 1: Run the deployment script**
```bash
cd docs/team-assistant/deployment/
./deploy.sh
```

**Step 2: Complete the VM setup**
```bash
# SSH into the VM
gcloud compute ssh openwebui-prod --zone=us-central1-a

# Run the VM setup script
sudo bash /tmp/vm-deploy-script.sh

# Deploy your code (choose one method):

# Method A: Git clone (if you have a repository)
git clone https://github.com/YOUR_USERNAME/team-assistant-open-webui.git temp_repo
mv temp_repo/* . && rm -rf temp_repo

# Method B: Manual file transfer (from your local machine)
# On your local machine:
# tar -czf openwebui-code.tar.gz --exclude='.git' --exclude='node_modules' .
# gcloud compute scp openwebui-code.tar.gz openwebui-prod:/opt/openwebui/ --zone=us-central1-a
# Back on VM:
# tar -xzf openwebui-code.tar.gz && rm openwebui-code.tar.gz
```

**Step 3: Start the application**
```bash
# On the VM:
cd /opt/openwebui
source .env.production
sudo docker-compose -f docker-compose.prod.yml up -d

# Check status
sudo docker-compose -f docker-compose.prod.yml ps
```

### Option 2: Manual Step-by-Step

Follow the complete guide in `gce_production_deployment_guide.md` for detailed instructions.

### Option 3: Cloud Shell (If gcloud not available locally)

1. Open [Google Cloud Shell](https://shell.cloud.google.com/)
2. Clone this repository: `git clone YOUR_REPO_URL`
3. Run the deployment script from Cloud Shell

## After Deployment

### 1. Access Your Application
```bash
# Get your VM's external IP
gcloud compute instances describe openwebui-prod --zone=us-central1-a --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

# Access via browser
https://YOUR_VM_IP
```

### 2. Set Up Your Domain (Optional)
```bash
# Update DNS records to point to your VM IP
# Then update SSL certificate:
gcloud compute ssl-certificates create openwebui-ssl \
    --domains=yourdomain.com \
    --global
```

### 3. Create First Admin User
- Navigate to your Open WebUI instance
- Register the first account (will be admin)
- Disable signups in admin settings

## Troubleshooting

### VM Not Accessible
```bash
# Check VM status
gcloud compute instances describe openwebui-prod --zone=us-central1-a

# Check firewall rules
gcloud compute firewall-rules list --filter="name~openwebui"

# SSH into VM and check logs
gcloud compute ssh openwebui-prod --zone=us-central1-a
sudo docker-compose -f /opt/openwebui/docker-compose.prod.yml logs
```

### Application Not Starting
```bash
# SSH into VM
gcloud compute ssh openwebui-prod --zone=us-central1-a

# Check Docker containers
sudo docker ps -a

# Check application logs
cd /opt/openwebui
sudo docker-compose -f docker-compose.prod.yml logs openwebui

# Restart if needed
sudo docker-compose -f docker-compose.prod.yml restart
```

### Database Connection Issues
```bash
# SSH into VM
gcloud compute ssh openwebui-prod --zone=us-central1-a

# Check Cloud SQL proxy
sudo docker logs cloud-sql-proxy

# Test database connection
sudo docker exec -it cloud-sql-proxy /bin/sh
# Inside container: nc -zv localhost 5432
```

## File Transfer Methods (Since Docker not available locally)

### Method 1: Git Repository (Recommended)
```bash
# On VM:
git clone https://github.com/YOUR_USERNAME/repo.git temp_repo
mv temp_repo/* . && rm -rf temp_repo
```

### Method 2: Direct File Transfer
```bash
# From local machine:
tar -czf openwebui-code.tar.gz --exclude='.git' --exclude='node_modules' .
gcloud compute scp openwebui-code.tar.gz openwebui-prod:/opt/openwebui/ --zone=us-central1-a

# On VM:
tar -xzf openwebui-code.tar.gz && rm openwebui-code.tar.gz
```

### Method 3: Cloud Storage Transfer
```bash
# From local machine:
gsutil cp -r . gs://ps-agent-sandbox-openwebui-storage/code/

# On VM:
gsutil cp -r gs://ps-agent-sandbox-openwebui-storage/code/* .
```

## Maintenance Commands

### Update Application
```bash
# SSH into VM
gcloud compute ssh openwebui-prod --zone=us-central1-a

cd /opt/openwebui

# Pull latest changes (if using git)
git pull origin main

# Rebuild and restart
sudo docker-compose -f docker-compose.prod.yml down
sudo docker-compose -f docker-compose.prod.yml up -d --build
```

### Backup Data
```bash
# Automated backups run daily at 2 AM
# Manual backup:
sudo /opt/openwebui/backup.sh
```

### Monitor Resources
```bash
# Check VM resources
gcloud compute instances describe openwebui-prod --zone=us-central1-a

# Check application status
sudo docker stats

# View logs
sudo docker-compose -f /opt/openwebui/docker-compose.prod.yml logs -f
```

## Security Notes

- 🔒 VM has automatic security updates enabled
- 🔒 Firewall configured for HTTP/HTTPS only
- 🔒 Database has automated backups
- 🔒 SSL certificates auto-renew
- 🔒 SSH key-based authentication only

## Cost Optimization

### Development/Testing
```bash
# Stop VM when not in use
gcloud compute instances stop openwebui-prod --zone=us-central1-a

# Start when needed
gcloud compute instances start openwebui-prod --zone=us-central1-a
```

### Production
- Monitor usage and downsize VM if possible
- Use committed use discounts for predictable workloads
- Set up billing alerts

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review VM startup logs: `sudo journalctl -u google-startup-scripts`
3. Check application logs: `sudo docker-compose -f /opt/openwebui/docker-compose.prod.yml logs`
4. Verify network connectivity: `curl -I http://localhost:8080`

## Next Steps

After successful deployment:
1. **Set up monitoring alerts** for your email
2. **Configure domain and SSL** for production use
3. **Test backup/restore** procedures
4. **Set up CI/CD pipeline** for automated deployments
5. **Configure user management** and access controls 