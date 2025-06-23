# Claude Code: Open WebUI Local Development with Google OAuth Setup

## Project Overview
I want to set up Open WebUI locally with Google OAuth authentication before deploying to Google Cloud. This is a development environment where I'll test OAuth integration, user management, and conversation management features.

## Current Status
- **No deployment yet** - starting fresh with local development
- **Goal**: Get Google OAuth working locally, then migrate to Google Cloud
- **Approach**: Use localhost with HTTP for initial development

## Immediate Objectives

### Phase 1: Local Development Setup
1. **Set up Open WebUI locally** using Docker Compose for easy management
2. **Configure Google OAuth** for localhost development environment
3. **Test complete OAuth flow** including user creation and role assignment
4. **Verify admin functionality** and user management features

### Phase 2: Preparation for Cloud Deployment
1. **Document working configuration** for easy migration
2. **Plan production environment variables** 
3. **Prepare OAuth URL updates** for domain transition

## Technical Requirements

### Local Environment Setup
I need help with:

#### Google Cloud Console Configuration
- Creating OAuth 2.0 credentials for localhost development
- Setting up correct redirect URIs for local testing
- Configuring authorized origins for `http://localhost:8080`
- Enabling required Google APIs

#### Docker Compose Configuration
- Complete `docker-compose.yml` with proper environment variables
- Port configuration (prefer port 3000 for the web interface)
- Volume management for persistent data
- Logging configuration for debugging

#### Environment Variables
```bash
# Core OAuth Settings
WEBUI_URL=http://localhost:8080
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true

# Google OAuth (need help with exact variable names)
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
GOOGLE_OAUTH_REDIRECT_URI=http://localhost:3000/oauth/google/callback

# Security settings for local development
WEBUI_SESSION_COOKIE_SAME_SITE=lax
ENABLE_LOGIN_FORM=false  # Disable password login, OAuth only
```

### Testing and Debugging
I need assistance with:

#### OAuth Flow Testing
- Step-by-step testing procedure for Google OAuth
- Common error scenarios and solutions
- Browser debugging techniques
- Log analysis for authentication issues

#### User Management Testing
- Verifying user creation after OAuth login
- Testing admin role assignment (first user = super admin)
- Group management configuration (basic setup)
- Permission testing workflow

## Specific Implementation Tasks

### 1. Google Cloud Console Setup
Help me:
- Navigate Google Cloud Console for OAuth setup
- Create proper web application OAuth client
- Configure redirect URIs correctly for localhost
- Enable necessary APIs (Google+ API, Identity API)
- Understand scopes needed for basic user info

### 2. Open WebUI Configuration
Assist with:
- Writing proper `docker-compose.yml` file
- Setting all required environment variables
- Understanding Open WebUI's OAuth environment variable naming
- Configuring logging for debugging

### 3. Initial Deployment and Testing
Guide me through:
- Starting the local environment
- Testing the OAuth flow step-by-step
- Debugging common issues (redirect loops, URL mismatches)
- Verifying user creation and admin assignment

### 4. Advanced Configuration (Optional for Phase 1)
Help me understand:
- Group management configuration
- Role mapping from Google to Open WebUI
- Custom claim handling
- Session management settings

## Environment Details
- **Development OS**: [Linux/macOS/Windows - specify your OS]
- **Docker**: Available and preferred deployment method
- **Domain**: localhost for development, will transition to custom domain
- **Port Preference**: 3000 for web interface
- **Database**: SQLite for local development (default)

## Expected Deliverables

### Immediate (Phase 1)
1. **Working Docker Compose configuration** with all environment variables
2. **Google Cloud Console setup instructions** with exact steps
3. **Testing procedure** to verify OAuth functionality
4. **Troubleshooting guide** for common localhost OAuth issues

### Preparation (Phase 2)
1. **Migration checklist** for moving to production
2. **Environment variable mapping** for production deployment
3. **OAuth URL update procedure** for domain transition
4. **Security considerations** for production deployment

## Known Considerations
- Google OAuth supports `http://localhost` for development
- Open WebUI has built-in OAuth support - not building from scratch
- First user automatically becomes super admin
- Session cookie settings affect OAuth callback success
- WEBUI_URL must be set correctly before enabling OAuth

## Success Criteria
- [ ] User can access Open WebUI at `http://localhost:3000`
- [ ] "Continue with Google" button appears on login page
- [ ] Google OAuth flow completes successfully
- [ ] User account is created automatically after Google authentication
- [ ] First user receives admin privileges
- [ ] Admin panel is accessible and functional
- [ ] Session persists properly between browser sessions

## Questions to Address
1. What are the exact environment variable names for Google OAuth in Open WebUI?
2. Are there any Open WebUI-specific OAuth configuration files needed?
3. What's the best way to debug OAuth callback issues in local development?
4. How should I handle the transition from localhost to production domain?
5. What are the minimal scopes needed for Google OAuth with Open WebUI?

Please provide detailed, step-by-step guidance for setting up this local development environment, with emphasis on getting the OAuth flow working reliably before considering cloud deployment.