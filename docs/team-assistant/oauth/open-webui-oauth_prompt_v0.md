# Claude Code: Open WebUI Google OAuth Integration

## Project Context
I'm working with an Open WebUI instance and need to implement Google SignIn authentication. Open WebUI already has OAuth support built-in, but I need help with the complete setup and configuration.

## Current State
- Open WebUI instance is running (specify your deployment method: Docker/Python/etc.)
- Google OAuth support exists but needs proper configuration
- Need to integrate with Google Cloud Console OAuth 2.0 setup

## Objectives
1. **Primary Goal**: Enable Google SignIn for Open WebUI with proper user creation and role assignment
2. **Secondary Goals**: 
   - Configure group management via Google OAuth claims
   - Set up role-based access control
   - Ensure secure redirect flow and session management
   - Test and debug the complete authentication flow

## Technical Requirements

### Environment Variables Setup
Help me configure these required environment variables:
```bash
# Core Configuration
WEBUI_URL=                    # My domain URL
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true

# Google OAuth Credentials
GOOGLE_OAUTH_CLIENT_ID=       # From Google Cloud Console
GOOGLE_OAUTH_CLIENT_SECRET=   # From Google Cloud Console  
GOOGLE_OAUTH_REDIRECT_URI=    # Callback URL

# Group & Role Management (Optional)
ENABLE_OAUTH_GROUP_MANAGEMENT=true
OAUTH_GROUP_CLAIM=groups
ENABLE_OAUTH_GROUP_CREATION=true
OAUTH_ALLOWED_ROLES=user,admin
OAUTH_ADMIN_ROLES=admin
OAUTH_ROLES_CLAIM=groups
```

### Google Cloud Console Configuration
I need assistance with:
1. Creating OAuth 2.0 credentials in Google Cloud Console
2. Configuring authorized redirect URIs correctly
3. Setting up consent screen appropriately
4. Enabling required APIs (Google+ API or Google Identity API)

## Specific Tasks

### 1. Google Cloud Console Setup
- Guide me through creating a new OAuth 2.0 client ID
- Help configure the authorized redirect URIs (should be: `https://mydomain.com/oauth/google/callback`)
- Set up OAuth consent screen with appropriate scopes
- Verify all required APIs are enabled

### 2. Open WebUI Configuration
- Help me set environment variables in my deployment method
- Verify configuration syntax and values
- Check for any additional configuration files needed
- Ensure proper restart procedures for config changes

### 3. Testing & Debugging
- Create test scenarios for OAuth flow
- Help debug common OAuth issues (redirect loops, invalid redirect URI, etc.)
- Verify user creation and role assignment
- Test group synchronization if configured

### 4. Security & Best Practices
- Review security settings for OAuth configuration
- Implement proper secret management
- Configure session security settings
- Set up proper domain/subdomain handling

## Environment Details
- **Deployment Method**: [Docker Compose / Docker / Python / etc.]
- **Domain**: [your-domain.com or localhost for testing]
- **Current Open WebUI Version**: [specify if known]
- **Operating System**: [Linux/macOS/Windows]

## Expected Deliverables
1. **Complete Google Cloud Console setup** with all required configurations
2. **Environment variable configuration** properly formatted for my deployment method
3. **Step-by-step testing procedure** to verify OAuth functionality
4. **Troubleshooting guide** for common issues
5. **Security checklist** to ensure safe deployment

## Known Issues & Considerations
- Some users report redirect loop issues with Google OAuth in Open WebUI
- Session cookie domain settings can affect OAuth callback success
- WEBUI_URL must be set correctly before enabling OAuth
- First user automatically becomes super admin

## Code Review & Implementation
Please help me:
- Review any existing configuration files
- Implement proper environment variable handling
- Set up monitoring/logging for OAuth events
- Create backup procedures for reverting changes if needed

Please provide detailed, step-by-step guidance with explanations for each configuration choice and help me implement this securely and efficiently.