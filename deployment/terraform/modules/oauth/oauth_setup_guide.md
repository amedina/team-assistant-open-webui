# OAuth Setup Guide for Open WebUI

## Prerequisites
This document outlines the manual steps required to configure Google OAuth for Open WebUI.

## Environment: staging
- **Project ID**: ps-team-assistant
- **OAuth Client ID**: 835224168961-4hc2hp91l58ss0epnuffu0lsqulodnqr.apps.googleusercontent.com
- **Redirect URIs**: https://your-staging-domain.com/auth/callback, https://staging-open-webui.run.app/auth/callback

## Manual Configuration Steps

### 1. OAuth Consent Screen Configuration
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services > OAuth consent screen**
3. Configure the consent screen with:
   - Application name: Open WebUI (staging)
   - User support email: alberotmedina@google.com
   - Developer contact information: alberotmedina@google.com
   - Application domain: TBD - Configure in variables
   - Privacy policy: TBD - Configure in variables
   - Terms of service: TBD - Configure in variables

### 2. OAuth Client Configuration
1. Go to **APIs & Services > Credentials**
2. Create OAuth 2.0 Client ID:
   - Application type: Web application
   - Name: Open WebUI staging
   - Authorized redirect URIs:
     - https://your-staging-domain.com/auth/callback
     - https://staging-open-webui.run.app/auth/callback

### 3. Scopes Configuration
Required scopes for Open WebUI:
- openid
- email
- profile

### 4. Secret Management
The OAuth client secret must be stored in Google Secret Manager:
- Secret ID: staging-open-webui-oauth_client_secret
- This is handled automatically by Terraform

### 5. Verification
After configuration, verify:
1. OAuth consent screen is published
2. Client ID is correctly configured
3. Redirect URIs match your application URLs
4. Secret is stored in Secret Manager

### 6. Testing
Test OAuth flow:
1. Navigate to your application
2. Click "Sign in with Google"
3. Verify consent screen appears
4. Complete authentication flow

## Troubleshooting
- **Invalid Client ID**: Verify client ID format and project
- **Redirect URI mismatch**: Check redirect URIs in OAuth configuration
- **Consent screen not published**: Ensure consent screen is published for external users
- **Secret not found**: Verify secret is stored in Secret Manager

## Security Notes
- Keep OAuth client secret secure
- Use HTTPS for all redirect URIs
- Regularly rotate client secrets
- Monitor OAuth usage in Cloud Console

## Support
For issues with OAuth configuration, contact: alberotmedina@google.com
