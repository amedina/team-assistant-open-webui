#!/usr/bin/env python3
"""
Test script for Agent Engine integration with Open WebUI
Run this to verify your Agent Engine setup is working correctly.
"""

import os
import sys
import asyncio
import aiohttp
import json
from pathlib import Path

# Add the backend to Python path
backend_path = Path(__file__).parent / "backend"
sys.path.insert(0, str(backend_path))

# Load environment variables from .env file
def load_env_file():
    """Load environment variables from .env file"""
    env_file = Path(__file__).parent / ".env"
    if env_file.exists():
        print(f"📁 Loading environment variables from {env_file}")
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    # Remove quotes if present
                    value = value.strip('"\'')
                    os.environ[key] = value
        print("✅ Environment file loaded")
    else:
        print(f"⚠️  No .env file found at {env_file}")
        print("💡 Make sure your .env file is in the project root directory")

# Load environment variables
load_env_file()

async def test_agent_engine_config():
    """Test Agent Engine configuration"""
    print("🔧 Testing Agent Engine Configuration...")
    
    # Test environment variables
    required_vars = [
        'AGENT_ENGINE_PROJECT_ID',
        'AGENT_ENGINE_LOCATION', 
        'AGENT_ENGINE_REASONING_ENGINE_ID'
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Missing required environment variables: {missing_vars}")
        return False
    
    print("✅ Environment variables configured")
    return True

async def test_google_auth():
    """Test Google Cloud authentication"""
    print("🔐 Testing Google Cloud Authentication...")
    
    try:
        from google.auth import default
        from google.oauth2 import service_account
        
        # Test authentication methods
        service_account_json = os.getenv('AGENT_ENGINE_SERVICE_ACCOUNT_JSON')
        service_account_json_file = os.getenv('AGENT_ENGINE_SERVICE_ACCOUNT_JSON_FILE')
        
        # Load from file if specified
        if service_account_json_file and not service_account_json:
            json_file_path = Path(service_account_json_file)
            if json_file_path.exists():
                print(f"📂 Loading service account from file: {json_file_path}")
                with open(json_file_path, 'r') as f:
                    service_account_json = f.read()
            else:
                print(f"❌ Service account file not found: {json_file_path}")
                return False
        
        if service_account_json:
            print("📋 Using Service Account JSON authentication...")
            print(f"🔍 Service Account JSON length: {len(service_account_json)} characters")
            
            # Debug: Show first and last few characters
            if len(service_account_json) > 20:
                print(f"🔍 JSON starts with: {service_account_json[:50]}...")
                print(f"🔍 JSON ends with: ...{service_account_json[-20:]}")
            else:
                print(f"⚠️  JSON seems too short: '{service_account_json}'")
            
            # Try to parse JSON
            try:
                credentials_info = json.loads(service_account_json)
                print("✅ JSON parsing successful")
                
                # Check if it has required fields
                required_fields = ['type', 'project_id', 'private_key', 'client_email']
                missing_fields = [field for field in required_fields if field not in credentials_info]
                
                if missing_fields:
                    print(f"⚠️  Missing required fields: {missing_fields}")
                    return False
                
                print(f"📧 Service Account Email: {credentials_info.get('client_email')}")
                print(f"🏗️  Project ID: {credentials_info.get('project_id')}")
                
                credentials = service_account.Credentials.from_service_account_info(
                    credentials_info,
                    scopes=['https://www.googleapis.com/auth/cloud-platform']
                )
                print("✅ Service Account authentication successful")
                
            except json.JSONDecodeError as e:
                print(f"❌ JSON parsing failed: {e}")
                print("💡 Make sure your service account JSON is properly formatted in the .env file")
                print("💡 Try using single quotes around the JSON and escape any internal quotes")
                return False
                
        else:
            print("🔑 Using default credentials...")
            credentials, project = default(scopes=['https://www.googleapis.com/auth/cloud-platform'])
            print(f"✅ Default authentication successful (project: {project})")
        
        return True
        
    except ImportError as e:
        print(f"❌ Missing Google Auth dependencies: {e}")
        return False
    except Exception as e:
        print(f"❌ Authentication failed: {e}")
        return False

async def test_agent_engine_api():
    """Test Agent Engine API endpoint"""
    print("🌐 Testing Agent Engine API connectivity...")
    
    try:
        from google.auth import default
        from google.oauth2 import service_account
        from google.auth.transport.requests import Request as GoogleRequest
        
        # Get credentials
        service_account_json = os.getenv('AGENT_ENGINE_SERVICE_ACCOUNT_JSON')
        if service_account_json:
            credentials_info = json.loads(service_account_json)
            credentials = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=['https://www.googleapis.com/auth/cloud-platform']
            )
        else:
            credentials, _ = default(scopes=['https://www.googleapis.com/auth/cloud-platform'])
        
        # Refresh token if needed
        if not credentials.valid:
            auth_req = GoogleRequest()
            credentials.refresh(auth_req)
        
        # Build API URL
        project_id = os.getenv('AGENT_ENGINE_PROJECT_ID')
        location = os.getenv('AGENT_ENGINE_LOCATION')
        reasoning_engine_id = os.getenv('AGENT_ENGINE_REASONING_ENGINE_ID')
        
        base_url = f"https://us-central1-aiplatform.googleapis.com/v1"
        api_url = f"{base_url}/projects/{project_id}/locations/{location}/reasoningEngines/{reasoning_engine_id}"
        
        headers = {
            "Authorization": f"Bearer {credentials.token}",
            "Content-Type": "application/json"
        }
        
        # Test basic connectivity (GET request to check if endpoint exists)
        async with aiohttp.ClientSession() as session:
            async with session.get(api_url, headers=headers) as response:
                if response.status == 200:
                    print("✅ Agent Engine API endpoint accessible")
                    return True
                elif response.status == 404:
                    print("❌ Agent Engine not found - check your reasoning engine ID")
                    return False
                elif response.status == 403:
                    print("❌ Access denied - check your credentials and permissions")
                    return False
                else:
                    text = await response.text()
                    print(f"⚠️  API returned status {response.status}: {text}")
                    return False
                    
    except Exception as e:
        print(f"❌ API connectivity test failed: {e}")
        return False

async def main():
    """Run all tests"""
    print("🚀 Agent Engine Integration Test\n")
    
    # Check if environment is loaded
    project_id = os.getenv('AGENT_ENGINE_PROJECT_ID')
    if not project_id:
        print("❌ Required environment variables not found!")
        print("\n📝 Please create a .env file in the project root with these variables:")
        print("   ENABLE_AGENT_ENGINE=true")
        print("   AGENT_ENGINE_PROJECT_ID=your-project-id")
        print("   AGENT_ENGINE_LOCATION=us-central1") 
        print("   AGENT_ENGINE_REASONING_ENGINE_ID=your-reasoning-engine-id")
        print("   AGENT_ENGINE_SERVICE_ACCOUNT_JSON='{...json...}'")
        print("\n🔍 Currently loaded environment variables:")
        agent_vars = {k: v for k, v in os.environ.items() if k.startswith('AGENT_ENGINE')}
        if agent_vars:
            for key, value in agent_vars.items():
                # Mask sensitive values
                if 'JSON' in key or 'KEY' in key:
                    value = f"{value[:20]}...{value[-10:]}" if len(value) > 30 else "***"
                print(f"   {key}={value}")
        else:
            print("   (No AGENT_ENGINE_* variables found)")
        print("\n💡 Make sure the .env file is in the same directory as this test script")
        return
    else:
        print(f"✅ Found AGENT_ENGINE_PROJECT_ID: {project_id}")
    
    tests = [
        test_agent_engine_config,
        test_google_auth,
        test_agent_engine_api
    ]
    
    results = []
    for test in tests:
        try:
            result = await test()
            results.append(result)
            print()
        except Exception as e:
            print(f"❌ Test {test.__name__} failed with error: {e}\n")
            results.append(False)
    
    # Summary
    passed = sum(results)
    total = len(results)
    
    print("="*50)
    print(f"📊 Test Results: {passed}/{total} passed")
    
    if passed == total:
        print("🎉 All tests passed! Agent Engine integration is ready.")
        print("\n🔄 Next steps:")
        print("   1. Start Open WebUI backend")
        print("   2. Navigate to the admin settings")
        print("   3. Configure Agent Engine in the UI")
        print("   4. Select 'Agent Engine' model in chat")
    else:
        print("⚠️  Some tests failed. Please fix the issues above.")

if __name__ == "__main__":
    asyncio.run(main()) 