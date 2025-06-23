# Open WebUI Non-Docker Setup Report: Local Development to Google Cloud

## Executive Summary

**Objective**: Set up Open WebUI locally with Google OAuth authentication using Python (no Docker) for local development, then deploy to Google Cloud.

**Key Finding**: Open WebUI fully supports Python-based installation without Docker, offering a simpler development experience and better corporate environment compatibility.

**Recommendation**: Use Python virtual environment with pip/uv installation for local development, then deploy to Google Cloud using App Engine, Cloud Run, or Compute Engine.

---

## Non-Docker Installation Overview

### Why Choose Python Over Docker?

**Corporate Compatibility**: 
- No containerization restrictions
- Standard Python development practices
- Easier security compliance

**Development Benefits**:
- Direct access to source code and configurations
- Better debugging capabilities  
- Hot reloading support for development
- No port mapping complexity

**Deployment Flexibility**:
- Multiple Google Cloud deployment options
- Easy environment variable management
- Standard Python packaging and deployment

### Supported Installation Methods

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **pip install** | Simple, familiar | Manual dependency management | Basic usage |
| **uv package manager** | Fast, modern Python tooling | Newer tool | Recommended by Open WebUI |
| **Source installation** | Full development access | More complex setup | Contributors/customizers |

---

## Technical Implementation Plan

### Phase 1: Local Development Setup

#### 1. Environment Preparation
```bash
# Requirements
- Python 3.11 (required)
- Git for source access
- Virtual environment tools

# Installation verification
python --version  # Must be 3.11+
pip --version
```

#### 2. Virtual Environment Setup
```bash
# Method 1: Standard venv
python -m venv open-webui-env
source open-webui-env/bin/activate  # Linux/macOS
open-webui-env\Scripts\activate     # Windows

# Method 2: UV (recommended)
uv venv open-webui-env --python 3.11
source open-webui-env/bin/activate
```

#### 3. Open WebUI Installation
```bash
# Simple installation
pip install open-webui

# Or with UV
uv pip install open-webui

# Verify installation
open-webui --help
```

#### 4. Google OAuth Configuration

**Environment Variables**:
```bash
WEBUI_URL=http://localhost:8080
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
ENABLE_LOGIN_FORM=false
GOOGLE_OAUTH_CLIENT_ID=your_client_id
GOOGLE_OAUTH_CLIENT_SECRET=your_client_secret
GOOGLE_OAUTH_REDIRECT_URI=http://localhost:8080/oauth/google/callback
DATA_DIR=./data
```

**Google Cloud Console Setup**:
- Create OAuth 2.0 client for "Web application"
- Authorized origins: `http://localhost:8080`
- Redirect URIs: `http://localhost:8080/oauth/google/callback`
- Enable Google+ API or Google Identity API

#### 5. Server Startup
```bash
# Method 1: Environment file
export $(cat .env | xargs)
open-webui serve --port 8080

# Method 2: Inline variables
WEBUI_URL=http://localhost:8080 ENABLE_OAUTH_SIGNUP=true open-webui serve --port 8080

# Access application
http://localhost:8080
```

### Phase 2: Google Cloud Deployment Options

#### Option A: Google App Engine (Recommended)
**Best for**: Simple deployment with minimal configuration

```yaml
# app.yaml
runtime: python311
env_variables:
  WEBUI_URL: "https://your-app.appspot.com"
  ENABLE_OAUTH_SIGNUP: "true"
  GOOGLE_OAUTH_CLIENT_ID: "your_client_id"
  GOOGLE_OAUTH_CLIENT_SECRET: "your_client_secret"
```

**Deployment**:
```bash
gcloud app deploy
```

#### Option B: Google Cloud Run
**Best for**: Serverless containerless deployment

```bash
# Deploy directly from source
gcloud run deploy open-webui \
  --source . \
  --platform managed \
  --region us-central1 \
  --set-env-vars WEBUI_URL=https://your-domain.com
```

#### Option C: Compute Engine VM
**Best for**: Full control and custom configurations

```bash
# Install on VM
sudo apt install python3.11 python3.11-venv
python3.11 -m venv /opt/openwebui/venv
source /opt/openwebui/venv/bin/activate
pip install open-webui

# Create systemd service
# Configure nginx reverse proxy
# Set up SSL certificates
```

---

## Advantages Over Docker Approach

### Development Experience
- **Direct file access**: No volume mounting complexity
- **Native debugging**: Use standard Python debugging tools
- **Hot reloading**: Faster development iterations
- **Environment isolation**: Standard virtual environment practices

### Corporate Environment Benefits
- **No container runtime**: Avoid Docker Desktop licensing/restrictions
- **Standard security**: Follow existing Python security policies
- **Simpler CI/CD**: Use standard Python build pipelines
- **Easier auditing**: Direct access to all source code and dependencies

### Deployment Flexibility
- **Multiple cloud options**: App Engine, Cloud Run, Compute Engine
- **Standard Python deployment**: Use familiar tools and practices
- **Environment variables**: Standard configuration management
- **Scaling**: Native cloud auto-scaling without container overhead

---

## Migration Path: Local to Cloud

### Step 1: Local Development
1. Set up Python virtual environment
2. Install Open WebUI with pip/uv
3. Configure Google OAuth for localhost
4. Test authentication flow locally
5. Verify admin functionality and user management

### Step 2: Production Preparation
1. Update OAuth settings for production domain
2. Configure production environment variables
3. Set up secure secret management
4. Plan database strategy (SQLite → PostgreSQL)

### Step 3: Cloud Deployment
1. Choose deployment method (App Engine/Cloud Run/VM)
2. Deploy application to Google Cloud
3. Update Google OAuth URLs for production
4. Test production authentication flow
5. Monitor and optimize performance

---

## Security Considerations

### Local Development
- Use virtual environments for isolation
- Store secrets in environment variables, not code
- Use localhost OAuth for development only
- Regular dependency updates

### Production Deployment
- Use Google Cloud Secret Manager for sensitive data
- Enable HTTPS and secure session cookies
- Configure proper CORS and security headers
- Regular security updates and monitoring

---

## Troubleshooting Guide

### Common Python Issues
- **Virtual environment activation**: Check shell and paths
- **Port binding**: Ensure port 8080 is available
- **Module imports**: Verify Open WebUI installation
- **Permission errors**: Check file system permissions

### OAuth Issues
- **Redirect URI mismatch**: Verify exact URL matching
- **Client ID/Secret**: Check environment variable loading
- **Session issues**: Verify cookie settings
- **API errors**: Check Google Console API enablement

### Cloud Deployment Issues
- **Environment variables**: Verify cloud platform configuration
- **Database connections**: Test cloud database connectivity
- **SSL certificates**: Ensure HTTPS configuration
- **Resource limits**: Check memory and CPU allocation

---

## Cost Analysis

### Local Development
- **Zero infrastructure cost**: Python installation only
- **Minimal resource usage**: Direct Python execution
- **Development efficiency**: Faster iteration cycles

### Cloud Deployment
- **App Engine**: Pay-per-use, automatic scaling
- **Cloud Run**: Pay-per-request, serverless
- **Compute Engine**: Predictable costs, full control

---

## Next Steps & Recommendations

### Immediate Actions
1. **Set up local Python environment** following the guide
2. **Configure Google OAuth** for localhost testing
3. **Test complete authentication flow** locally
4. **Document working configuration** for team reference

### Production Planning
1. **Choose cloud deployment method** based on requirements
2. **Plan domain and SSL certificate** setup
3. **Design user management strategy** and admin policies
4. **Set up monitoring and logging** for production

### Long-term Considerations
1. **Database scaling strategy** (SQLite → Cloud SQL)
2. **User authentication integration** with company SSO
3. **Backup and disaster recovery** planning
4. **Performance optimization** and caching strategies

---

## Conclusion

The non-Docker approach offers significant advantages for corporate environments and provides a cleaner development experience. Python-based installation is fully supported by Open WebUI and offers better debugging, easier deployment, and standard development practices.

**Key Success Factors**:
- Use Python 3.11 with virtual environments
- Follow OAuth configuration carefully
- Test thoroughly in local environment before cloud deployment
- Choose appropriate Google Cloud deployment method for your needs

This approach provides a solid foundation for both local development and scalable cloud deployment while maintaining corporate security and compliance requirements.