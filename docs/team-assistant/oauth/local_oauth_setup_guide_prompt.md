# Open WebUI Local Development Setup with Google OAuth

## Phase 1: Local Development Environment

### Step 1: Google Cloud Console Setup for Local Development

#### Create OAuth 2.0 Credentials
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **OAuth client ID**
5. Choose **Web application** as the application type
6. Configure the OAuth client:

**Application Name**: `Open WebUI Local Development`

**Authorized JavaScript origins**:
- `http://localhost:3000`
- `http://127.0.0.1:3000`
- `http://localhost:8080` (if using different port)

**Authorized redirect URIs**:
- `http://localhost:3000/oauth/google/callback`
- `http://127.0.0.1:3000/oauth/google/callback`
- `http://localhost:8080/oauth/google/callback` (backup port)

#### Enable Required APIs
1. Go to **APIs & Services** > **Library**
2. Enable these APIs:
   - **Google+ API** (for user profile info)
   - **Google Identity and Access Management (IAM) API**

#### Copy Credentials
- Save the **Client ID** and **Client Secret** for environment configuration

### Step 2: Open WebUI Local Installation

#### Option A: Docker Compose (Recommended)
Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui-dev
    volumes:
      - open-webui-data:/app/backend/data
    ports:
      - "3000:8080"
    environment:
      # Core Configuration
      - WEBUI_URL=http://localhost:3000
      - ENABLE_OAUTH_SIGNUP=true
      - OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
      
      # Disable default authentication temporarily during OAuth setup
      - ENABLE_LOGIN_FORM=false
      
      # Google OAuth Configuration
      - GOOGLE_OAUTH_CLIENT_ID=your_google_client_id_here
      - GOOGLE_OAUTH_CLIENT_SECRET=your_google_client_secret_here
      - GOOGLE_OAUTH_REDIRECT_URI=http://localhost:3000/oauth/google/callback
      
      # Optional: Group and Role Management
      - ENABLE_OAUTH_GROUP_MANAGEMENT=false  # Start simple, enable later
      - OAUTH_GROUP_CLAIM=groups
      - ENABLE_OAUTH_GROUP_CREATION=false
      
      # Development Settings
      - WEBUI_AUTH=true
      - DEFAULT_USER_ROLE=user
      
      # Security (relaxed for local development)
      - WEBUI_SESSION_COOKIE_SAME_SITE=lax
      
    restart: unless-stopped
    
volumes:
  open-webui-data:
```

#### Option B: Environment Variables File
Create `.env` file:

```bash
# Core Configuration
WEBUI_URL=http://localhost:3000
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
ENABLE_LOGIN_FORM=false

# Google OAuth
GOOGLE_OAUTH_CLIENT_ID=your_google_client_id_here
GOOGLE_OAUTH_CLIENT_SECRET=your_google_client_secret_here
GOOGLE_OAUTH_REDIRECT_URI=http://localhost:3000/oauth/google/callback

# Development Settings
WEBUI_AUTH=true
DEFAULT_USER_ROLE=user
WEBUI_SESSION_COOKIE_SAME_SITE=lax
```

### Step 3: Initial Testing

#### Launch Application
```bash
# Using Docker Compose
docker-compose up -d

# Check logs
docker-compose logs -f open-webui
```

#### Test OAuth Flow
1. Open browser to `http://localhost:3000`
2. You should see OAuth login options instead of username/password
3. Click "Continue with Google"
4. Complete Google authentication
5. Should redirect back to Open WebUI with user created

#### Troubleshooting Common Issues

**Redirect URI Mismatch Error**:
- Verify exact match between Google Console and environment variable
- Check that ports match (3000 vs 8080)
- Ensure no trailing slashes

**Login Loop Issues**:
- Check `WEBUI_SESSION_COOKIE_SAME_SITE` setting
- Verify `WEBUI_URL` is set correctly
- Clear browser cookies/cache

**HTTPS Errors in Development**:
- OAuth should work with HTTP on localhost
- If issues persist, use ngrok tunnel (see advanced section)

### Step 4: Advanced Local Development (Optional)

#### Using HTTPS Locally with ngrok
If you encounter HTTPS requirements:

```bash
# Install ngrok
npm install -g ngrok

# Start tunnel
ngrok http 3000

# Update Google Console with ngrok URL
# Example: https://abc123.ngrok.io/oauth/google/callback
```

#### Enable Group Management (Advanced)
Once basic OAuth works, enhance with group management:

```yaml
environment:
  - ENABLE_OAUTH_GROUP_MANAGEMENT=true
  - OAUTH_GROUP_CLAIM=groups
  - ENABLE_OAUTH_GROUP_CREATION=true
  - OAUTH_ALLOWED_ROLES=user,admin
  - OAUTH_ADMIN_ROLES=admin
  - OAUTH_ROLES_CLAIM=groups
```

### Step 5: User Management Testing

#### Create Test Users
1. Log in with your Google account (becomes super admin)
2. Test with additional Google accounts
3. Verify user roles and permissions
4. Test group assignments if enabled

#### Admin Panel Access
- Navigate to `http://localhost:3000/admin`
- Manage users, roles, and permissions
- Test model access controls

## Phase 2: Preparation for Google Cloud Deployment

### Step 1: Environment Configuration for Cloud

#### Production Environment Variables
```bash
# Production Configuration
WEBUI_URL=https://your-domain.com
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
ENABLE_LOGIN_FORM=false

# Google OAuth (same credentials, different redirect)
GOOGLE_OAUTH_CLIENT_ID=your_google_client_id_here
GOOGLE_OAUTH_CLIENT_SECRET=your_google_client_secret_here
GOOGLE_OAUTH_REDIRECT_URI=https://your-domain.com/oauth/google/callback

# Production Security Settings
WEBUI_SESSION_COOKIE_SAME_SITE=strict
WEBUI_SESSION_COOKIE_SECURE=true

# Database (for scalability)
DATABASE_URL=postgresql://user:pass@db-host:5432/openwebui
```

### Step 2: Google Cloud Console Updates for Production

#### Update OAuth Configuration
1. Go back to Google Cloud Console > Credentials
2. Edit your OAuth 2.0 client
3. Add production URLs:

**Authorized JavaScript origins**:
- `https://your-domain.com`

**Authorized redirect URIs**:
- `https://your-domain.com/oauth/google/callback`

#### Domain Verification (if required)
- Verify domain ownership in Google Console
- Add TXT records to DNS if prompted

### Step 3: Infrastructure Preparation

#### Google Cloud Run Configuration
```yaml
# cloud-run-config.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: open-webui
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containers:
      - image: ghcr.io/open-webui/open-webui:main
        ports:
        - containerPort: 8080
        env:
        - name: WEBUI_URL
          value: "https://your-domain.com"
        - name: ENABLE_OAUTH_SIGNUP
          value: "true"
        # Add all other environment variables
```

#### Database Setup (Cloud SQL)
```bash
# Create Cloud SQL instance
gcloud sql instances create openwebui-db \
  --database-version=POSTGRES_13 \
  --tier=db-f1-micro \
  --region=us-central1

# Create database
gcloud sql databases create openwebui \
  --instance=openwebui-db
```

## Testing Checklist

### Local Development Testing
- [ ] OAuth login flow works
- [ ] User creation and role assignment
- [ ] Session persistence
- [ ] Admin panel access
- [ ] Model access controls

### Pre-Production Testing
- [ ] Environment variables properly configured
- [ ] HTTPS redirect URIs configured
- [ ] Database connections tested
- [ ] Backup and restore procedures
- [ ] SSL/TLS certificates configured

### Security Checklist
- [ ] Client secrets stored securely
- [ ] Database credentials encrypted
- [ ] HTTPS enforced in production
- [ ] Session security configured
- [ ] Firewall rules applied

## Deployment Strategy

### Approach 1: Gradual Migration
1. Test everything locally
2. Deploy to staging environment
3. Update OAuth URLs incrementally
4. Migrate production with minimal downtime

### Approach 2: Blue-Green Deployment
1. Set up complete production environment
2. Test with separate OAuth client
3. Switch DNS/load balancer
4. Update OAuth configuration

## Monitoring and Maintenance

### Key Metrics to Monitor
- OAuth success/failure rates
- User session durations
- API response times
- Error logs for authentication issues

### Regular Maintenance Tasks
- Monitor OAuth token expiration
- Update Google OAuth credentials annually
- Review user permissions quarterly
- Backup user data and configurations