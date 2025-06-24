# Open WebUI Google Compute Engine Deployment Assistant

I need your help deploying my Open WebUI implementation to Google Compute Engine. Please act as my expert cloud deployment assistant and guide me through this process step-by-step.

## Project Context
- **Application**: Open WebUI (self-hosted ChatGPT-style web interface)
- **Target Platform**: Google Compute Engine (VM-based deployment)
- **Current Status**: [FILL IN: e.g., "Running locally with Docker" / "Have source code ready" / etc.]
- **Technical Stack**: [FILL IN: e.g., "Docker containers" / "Python/Node.js" / etc.]

## Deployment Requirements
- **VM Specifications**: Recommend appropriate instance type, CPU, RAM, and storage
- **Operating System**: Suggest best OS (Ubuntu/Debian/CentOS) for this deployment
- **Security**: Implement proper firewall rules, SSL/TLS, and access controls
- **Persistence**: Ensure chat history and user data survive VM restarts
- **Monitoring**: Basic health checks and logging setup
- **Cost Optimization**: Suggest cost-effective configurations

## What I Need From You

### 1. **Pre-Deployment Planning**
- Recommend optimal GCE instance configuration
- List all prerequisites and dependencies
- Suggest network and security configurations
- Estimate monthly costs

### 2. **Step-by-Step Deployment Guide**
- VM creation and initial setup commands
- Docker installation and configuration
- Open WebUI installation and configuration
- Environment variables and secrets management
- Database/storage setup (if needed)

### 3. **Infrastructure as Code**
- Provide gcloud CLI commands for reproducible deployment
- Create startup scripts for automated setup
- Suggest backup and disaster recovery strategies

### 4. **Security Hardening**
- Firewall configuration
- SSL certificate setup (Let's Encrypt or managed certificates)
- User authentication and access controls
- Regular security updates automation

### 5. **Operational Scripts**
- Deployment automation scripts
- Update/upgrade procedures
- Backup scripts
- Monitoring and alerting setup

## Specific Questions to Address
1. What's the recommended VM size for 100 users?
2. How do I handle persistent storage for user data and chat history?
3. What's the best way to manage environment variables and API keys securely?
4. How can I set up automatic backups of user data?
5. What monitoring should I implement to ensure uptime?
6. How do I configure domain name and SSL certificates?

## Current Environment Details
- **Google Cloud Project ID**: ps-agent-sandbox
- **Preferred Region**: us-central1
- **Domain Name**: No domain assigned yet
- **Expected Users**: 10-100
- **Budget Constraints**: None

## Deliverables Requested
1. Complete deployment checklist
2. All necessary command sequences
3. Configuration file templates
4. Troubleshooting guide for common issues
5. Maintenance and update procedures

Please provide detailed, copy-paste ready commands and explain each step. Assume I'm comfortable with command line but may need guidance on GCP-specific configurations.

Start with the pre-deployment planning and then provide the complete step-by-step implementation guide.