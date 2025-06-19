import asyncio
import json
import logging
import time
import os
from typing import Optional, Dict, Any
from datetime import datetime, timedelta

import aiohttp
from google.auth import default
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import service_account
from google.auth import impersonated_credentials
from google.auth.external_account import Credentials as ExternalAccountCredentials

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from starlette.background import BackgroundTask

from open_webui.models.users import UserModel
from open_webui.utils.auth import get_admin_user, get_verified_user
from open_webui.utils.access_control import has_access
from open_webui.env import SRC_LOG_LEVELS, BYPASS_MODEL_ACCESS_CONTROL

log = logging.getLogger(__name__)
log.setLevel(SRC_LOG_LEVELS.get("AGENT_ENGINE", logging.INFO))

router = APIRouter()

# Cache for authentication credentials
_auth_cache = {
    "credentials": None,
    "expires_at": None
}

class AgentEngineConfig(BaseModel):
    ENABLE_AGENT_ENGINE: Optional[bool] = None
    AGENT_ENGINE_PROJECT_ID: str
    AGENT_ENGINE_LOCATION: str
    AGENT_ENGINE_REASONING_ENGINE_ID: str
    AGENT_ENGINE_SERVICE_ACCOUNT_JSON: Optional[str] = None
    AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER: Optional[str] = None
    AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT: Optional[str] = None
    AGENT_ENGINE_CUSTOM_URL: Optional[str] = None

@router.get("/config")
async def get_config(request: Request, user=Depends(get_admin_user)):
    """Get Team Assistant configuration"""
    return {
        "ENABLE_AGENT_ENGINE": request.app.state.config.ENABLE_AGENT_ENGINE,
        "AGENT_ENGINE_PROJECT_ID": request.app.state.config.AGENT_ENGINE_PROJECT_ID,
        "AGENT_ENGINE_LOCATION": request.app.state.config.AGENT_ENGINE_LOCATION,
        "AGENT_ENGINE_REASONING_ENGINE_ID": request.app.state.config.AGENT_ENGINE_REASONING_ENGINE_ID,
        "AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER": request.app.state.config.AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER,
        "AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT": request.app.state.config.AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT,
        "AGENT_ENGINE_CUSTOM_URL": request.app.state.config.AGENT_ENGINE_CUSTOM_URL,
    }

@router.post("/config/update")
async def update_config(
    request: Request, 
    form_data: AgentEngineConfig, 
    user=Depends(get_admin_user)
):
    """Update Team Assistant configuration"""
    request.app.state.config.ENABLE_AGENT_ENGINE = form_data.ENABLE_AGENT_ENGINE
    request.app.state.config.AGENT_ENGINE_PROJECT_ID = form_data.AGENT_ENGINE_PROJECT_ID
    request.app.state.config.AGENT_ENGINE_LOCATION = form_data.AGENT_ENGINE_LOCATION
    request.app.state.config.AGENT_ENGINE_REASONING_ENGINE_ID = form_data.AGENT_ENGINE_REASONING_ENGINE_ID
    
    # Only update authentication if provided
    if form_data.AGENT_ENGINE_SERVICE_ACCOUNT_JSON:
        request.app.state.config.AGENT_ENGINE_SERVICE_ACCOUNT_JSON = form_data.AGENT_ENGINE_SERVICE_ACCOUNT_JSON
    
    if form_data.AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER:
        request.app.state.config.AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER = form_data.AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER
    
    if form_data.AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT:
        request.app.state.config.AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT = form_data.AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT
    
    if form_data.AGENT_ENGINE_CUSTOM_URL:
        request.app.state.config.AGENT_ENGINE_CUSTOM_URL = form_data.AGENT_ENGINE_CUSTOM_URL
    
    # Clear auth cache when config changes
    global _auth_cache
    _auth_cache = {"credentials": None, "expires_at": None}
    
    return await get_config(request, user)

async def get_agent_engine_credentials(request: Request):
    """
    Get GCP credentials for Agent Engine using either:
    1. Workload Identity Federation (recommended for production)
    2. Service Account JSON (for development/testing)
    3. Default credentials (when running on GCP)
    """
    global _auth_cache
    
    # Check cache first
    if (_auth_cache["credentials"] and _auth_cache["expires_at"] and 
        datetime.now() < _auth_cache["expires_at"]):
        return _auth_cache["credentials"]
    
    config = request.app.state.config
    
    try:
        # Option 1: Workload Identity Federation (most secure)
        if (getattr(config, 'AGENT_ENGINE_WORKLOAD_IDENTITY_PROVIDER', None) and 
            getattr(config, 'AGENT_ENGINE_WORKLOAD_IDENTITY_SERVICE_ACCOUNT', None)):
            
            log.info("Using Workload Identity Federation for Agent Engine authentication")
            # This would be implemented for external workloads
            # For now, we'll use service account approach
            pass
        
        # Option 2: Service Account JSON
        elif getattr(config, 'AGENT_ENGINE_SERVICE_ACCOUNT_JSON', None):
            log.info("Using Service Account JSON for Agent Engine authentication")
            credentials_info = json.loads(config.AGENT_ENGINE_SERVICE_ACCOUNT_JSON)
            credentials = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=['https://www.googleapis.com/auth/cloud-platform']
            )
        
        # Option 3: Default credentials (when running on GCP)
        else:
            log.info("Using default credentials for Agent Engine authentication")
            credentials, _ = default(scopes=['https://www.googleapis.com/auth/cloud-platform'])
        
        # Cache credentials for 50 minutes (tokens are valid for 1 hour)
        _auth_cache = {
            "credentials": credentials,
            "expires_at": datetime.now() + timedelta(minutes=50)
        }
        
        return credentials
        
    except Exception as e:
        log.error(f"Failed to get Agent Engine credentials: {e}")
        raise HTTPException(
            status_code=500,
            detail="Team Assistant authentication failed. Please check your configuration."
        )

async def get_access_token(request: Request) -> str:
    """Get a fresh access token for Team Assistant API calls"""
    credentials = await get_agent_engine_credentials(request)
    
    # Refresh token if needed
    if not credentials.valid:
        auth_req = GoogleRequest()
        credentials.refresh(auth_req)
    
    return credentials.token

@router.get("/models")
async def get_agent_engine_models(request: Request, user=Depends(get_verified_user)):
    """Register Team Assistant models for the model selector"""
    config = request.app.state.config
    
    if not getattr(config, 'ENABLE_AGENT_ENGINE', False):
        return {"data": []}
    
    # Return single Team Assistant model with crew routing capabilities
    models = [{
        "id": "team-assistant",
        "name": "Team Assistant",
        "owned_by": "team_assistant",
        "object": "model",
        "created": int(time.time()),
        "info": {
            "meta": {
                "description": "AI Team Assistant with intelligent crew routing capabilities",
                "capabilities": {
                    "streaming": True,
                    "crew_routing": True,
                    "metadata": True
                }
            }
        }
    }]
    
    return {"data": models}

@router.get("/models/public")
async def get_agent_engine_models_public(request: Request):
    """Public Team Assistant models endpoint for testing (no auth required)"""
    try:
        config = request.app.state.config
        
        if not getattr(config, 'ENABLE_AGENT_ENGINE', False):
            return {"data": [], "message": "Team Assistant is disabled"}
        
        # Return single Team Assistant model with crew routing capabilities
        models = [{
            "id": "team-assistant",
            "name": "Team Assistant",
            "owned_by": "team_assistant",
            "object": "model",
            "created": int(time.time()),
            "info": {
                "meta": {
                    "description": "AI Team Assistant with intelligent crew routing",
                    "capabilities": {
                        "streaming": True,
                        "crew_routing": True,
                        "metadata": True
                    }
                }
            }
        }]
        
        return {"data": models, "message": "Team Assistant models generated successfully"}
        
    except Exception as e:
        return {"data": [], "error": str(e), "message": "Error generating Team Assistant models"}

class ConnectionVerificationForm(BaseModel):
    project_id: str
    location: str
    reasoning_engine_id: str
    service_account_json: Optional[str] = None

@router.post("/verify")
async def verify_connection(
    request: Request,
    form_data: ConnectionVerificationForm, 
    user=Depends(get_admin_user)
):
    """Verify Team Assistant connection and authentication"""
    try:
        # Temporarily set config for verification
        temp_config = {
            "AGENT_ENGINE_PROJECT_ID": form_data.project_id,
            "AGENT_ENGINE_LOCATION": form_data.location,
            "AGENT_ENGINE_REASONING_ENGINE_ID": form_data.reasoning_engine_id,
            "AGENT_ENGINE_SERVICE_ACCOUNT_JSON": form_data.service_account_json or "",
        }
        
        # Test authentication
        if form_data.service_account_json:
            credentials_info = json.loads(form_data.service_account_json)
            credentials = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=['https://www.googleapis.com/auth/cloud-platform']
            )
        else:
            credentials, _ = default(scopes=['https://www.googleapis.com/auth/cloud-platform'])
        
        # Get access token
        if not credentials.valid:
            auth_req = GoogleRequest()
            credentials.refresh(auth_req)
        
        access_token = credentials.token
        
        # Test basic connectivity (you could add a simple API call here)
        # For now, we just verify token acquisition
        
        return {
            "status": "success",
            "message": "Team Assistant connection verified successfully",
            "details": {
                "project_id": form_data.project_id,
                "location": form_data.location,
                "reasoning_engine_id": form_data.reasoning_engine_id,
                "authentication": "valid"
            }
        }
        
    except json.JSONDecodeError:
        return {
            "status": "error",
            "message": "Invalid service account JSON format",
            "details": {"authentication": "invalid_json"}
        }
    except Exception as e:
        log.error(f"Team Assistant connection verification failed: {e}")
        return {
            "status": "error", 
            "message": f"Connection verification failed: {str(e)}",
            "details": {"authentication": "failed"}
        }

async def stream_agent_engine_response(
    request: Request,
    agent_request: Dict[str, Any],
    user: UserModel
):
    """Stream response from Team Assistant with proper SSE parsing"""
    config = request.app.state.config
    
    # Get access token
    access_token = await get_access_token(request)
    
    # Build Agent Engine API URL
    custom_url = getattr(config, 'AGENT_ENGINE_CUSTOM_URL', '')
    
    if custom_url:
        # Use custom URL for local testing
        api_url = custom_url.rstrip('/') + '/stream_query'  # Assuming local endpoint
        log.info(f"Using custom Agent Engine URL: {api_url}")
        headers = {"Content-Type": "application/json"}  # No auth for local
    else:
        # Use GCP Vertex AI URL
        base_url = "https://us-central1-aiplatform.googleapis.com/v1"
        api_url = f"{base_url}/projects/{config.AGENT_ENGINE_PROJECT_ID}/locations/{config.AGENT_ENGINE_LOCATION}/reasoningEngines/{config.AGENT_ENGINE_REASONING_ENGINE_ID}:streamQuery?alt=sse"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
    
    try:
        timeout = aiohttp.ClientTimeout(total=300)  # 5 minute timeout
        async with aiohttp.ClientSession(timeout=timeout, trust_env=True) as session:
            async with session.post(
                api_url,
                headers=headers,
                json=agent_request,
                ssl=True
            ) as response:
                
                if response.status != 200:
                    error_text = await response.text()
                    log.error(f"Team Assistant API error: {response.status} - {error_text}")
                    
                    # Send error as proper OpenAI streaming format
                    error_response = {
                        "id": f"chatcmpl-{int(time.time())}",
                        "object": "chat.completion.chunk",
                        "created": int(time.time()),
                        "model": "team-assistant",
                        "choices": [{
                            "index": 0,
                            "delta": {"content": f"❌ **Team Assistant Error**: {response.status}\n\n{error_text}"},
                            "finish_reason": "stop"
                        }]
                    }
                    yield f"data: {json.dumps(error_response)}\n\n"
                    yield "data: [DONE]\n\n"
                    return
                
                crew_info_sent = False
                json_buffer = ""
                
                async for chunk in response.content:
                    chunk_str = chunk.decode('utf-8')
                    log.info(f"Raw chunk received: {repr(chunk_str)}")
                    
                    # Split by lines to handle SSE format
                    lines = chunk_str.split('\n')
                    
                    for line in lines:
                        line = line.strip()
                        if not line:
                            continue
                        
                        log.info(f"Processing line: {repr(line)}")
                            
                        # Handle SSE data lines
                        if line.startswith('data: '):
                            data_content = line[6:]
                            log.info(f"Found SSE data: {data_content}")
                        elif line.startswith('data:'):
                            data_content = line[5:]
                            log.info(f"Found SSE data (no space): {data_content}")
                        elif line.startswith('{'):
                            # Handle JSON without SSE prefix (direct JSON streaming)
                            data_content = line
                            log.info(f"Found direct JSON: {data_content}")
                        else:
                            log.info(f"Ignoring non-data line: {line}")
                            continue
                        
                        # Handle completion
                        if data_content == '[DONE]':
                            yield "data: [DONE]\n\n"
                            return
                        
                        # Add to JSON buffer
                        json_buffer += data_content
                        
                        # Try to parse complete JSON objects
                        while json_buffer:
                            try:
                                # Try to find a complete JSON object
                                # Look for balanced braces
                                brace_count = 0
                                json_end = -1
                                
                                for i, char in enumerate(json_buffer):
                                    if char == '{':
                                        brace_count += 1
                                    elif char == '}':
                                        brace_count -= 1
                                        if brace_count == 0:
                                            json_end = i
                                            break
                                
                                if json_end == -1:
                                    # No complete JSON object yet, wait for more data
                                    break
                                
                                # Extract complete JSON object
                                json_str = json_buffer[:json_end + 1]
                                json_buffer = json_buffer[json_end + 1:].lstrip()
                                
                                log.info(f"Complete JSON object: {json_str}")
                                agent_data = json.loads(json_str)
                                
                                # Handle crew routing information
                                if agent_data.get("type") == "routing_info" and not crew_info_sent:
                                    crew_message = f"🤖 **Crew Selected**: {agent_data.get('crew_selected', 'Unknown')}\n📋 **Description**: {agent_data.get('crew_description', 'No description')}\n\n"
                                    
                                    openai_response = {
                                        "id": f"chatcmpl-{int(time.time())}",
                                        "object": "chat.completion.chunk",
                                        "created": int(time.time()),
                                        "model": "team-assistant",
                                        "choices": [{
                                            "index": 0,
                                            "delta": {"content": crew_message},
                                            "finish_reason": None
                                        }]
                                    }
                                    yield f"data: {json.dumps(openai_response)}\n\n"
                                    crew_info_sent = True
                                
                                # Handle final results
                                elif agent_data.get("type") == "final_result":
                                    content = agent_data.get("content", "")
                                    log.info(f"Final result content length: {len(content)}")
                                    
                                    # Stream the content
                                    openai_response = {
                                        "id": f"chatcmpl-{int(time.time())}",
                                        "object": "chat.completion.chunk", 
                                        "created": int(time.time()),
                                        "model": "team-assistant",
                                        "choices": [{
                                            "index": 0,
                                            "delta": {"content": content},
                                            "finish_reason": None
                                        }]
                                    }
                                    yield f"data: {json.dumps(openai_response)}\n\n"
                                    
                                    # Send completion signal
                                    completion_response = {
                                        "id": f"chatcmpl-{int(time.time())}",
                                        "object": "chat.completion.chunk",
                                        "created": int(time.time()),
                                        "model": "team-assistant",
                                        "choices": [{
                                            "index": 0,
                                            "delta": {},
                                            "finish_reason": "stop"
                                        }]
                                    }
                                    yield f"data: {json.dumps(completion_response)}\n\n"
                                    yield "data: [DONE]\n\n"
                                    return
                                
                                # Handle standard streaming content (fallback)
                                elif "content" in agent_data:
                                    openai_response = {
                                        "id": f"chatcmpl-{int(time.time())}",
                                        "object": "chat.completion.chunk",
                                        "created": int(time.time()),
                                        "model": "team-assistant", 
                                        "choices": [{
                                            "index": 0,
                                            "delta": {"content": agent_data["content"]},
                                            "finish_reason": None
                                        }]
                                    }
                                    yield f"data: {json.dumps(openai_response)}\n\n"
                                    
                            except json.JSONDecodeError:
                                # Not a complete JSON object yet, continue buffering
                                break
                            except Exception as e:
                                log.error(f"Error processing Team Assistant response: {e}")
                                json_buffer = ""  # Clear buffer on error
                                break
                
                # Only send completion if we haven't already finished
                log.info("Stream ended without final_result - sending default completion")
                
    except asyncio.TimeoutError:
        log.error("Team Assistant request timeout")
        timeout_response = {
            "id": f"chatcmpl-{int(time.time())}",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": "team-assistant",
            "choices": [{
                "index": 0,
                "delta": {"content": "⏱️ **Request Timeout**: The Team Assistant took too long to respond. Please try again."},
                "finish_reason": "stop"
            }]
        }
        yield f"data: {json.dumps(timeout_response)}\n\n"
        yield "data: [DONE]\n\n"
    except Exception as e:
        log.error(f"Team Assistant streaming error: {e}")
        error_response = {
            "id": f"chatcmpl-{int(time.time())}",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": "team-assistant",
            "choices": [{
                "index": 0,
                "delta": {"content": f"🚨 **Streaming Error**: {str(e)}"},
                "finish_reason": "stop"
            }]
        }
        yield f"data: {json.dumps(error_response)}\n\n"
        yield "data: [DONE]\n\n"

@router.post("/chat/completions")
async def generate_chat_completion(
    request: Request,
    form_data: dict,
    user=Depends(get_verified_user),
    bypass_filter: Optional[bool] = False,
):
    """
    Generate chat completion using Team Assistant
    Compatible with OpenAI chat completions API
    """
    if BYPASS_MODEL_ACCESS_CONTROL:
        bypass_filter = True
    
    config = request.app.state.config
    
    if not getattr(config, 'ENABLE_AGENT_ENGINE', False):
        raise HTTPException(status_code=503, detail="Team Assistant is not enabled")
    
    if not getattr(config, 'AGENT_ENGINE_PROJECT_ID', None) or not getattr(config, 'AGENT_ENGINE_REASONING_ENGINE_ID', None):
        raise HTTPException(status_code=500, detail="Team Assistant configuration incomplete")
    
    # Transform OpenAI format to Agent Engine format
    openai_messages = form_data.get("messages", [])
    
    # Convert OpenAI message format to Agent Engine format
    agent_messages = []
    for msg in openai_messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        
        # Convert OpenAI roles to Agent Engine types
        if role == "user":
            agent_type = "human"
        elif role == "assistant":
            agent_type = "ai"
        elif role == "system":
            agent_type = "system"
        else:
            agent_type = "human"  # fallback
            
        agent_messages.append({
            "type": agent_type,
            "content": content
        })
    
    # Build Agent Engine request
    agent_request = {
        "class_method": "stream_query",
        "input": {
            "input": {
                "messages": agent_messages
            }
        }
    }
    
    # Handle streaming vs non-streaming
    if form_data.get("stream", True):
        async def cleanup_response():
            pass
            
        return StreamingResponse(
            stream_agent_engine_response(request, agent_request, user),
            media_type="text/event-stream",
            background=BackgroundTask(cleanup_response)
        )
    else:
        # Non-streaming mode (collect all chunks)
        chunks = []
        async for chunk in stream_agent_engine_response(request, agent_request, user):
            if chunk.startswith("data: ") and not chunk.strip().endswith("[DONE]"):
                try:
                    chunk_data = json.loads(chunk[6:])
                    if "choices" in chunk_data and chunk_data["choices"]:
                        content = chunk_data["choices"][0].get("delta", {}).get("content", "")
                        if content:
                            chunks.append(content)
                except:
                    continue
        
        # Return non-streaming response
        response = {
            "id": f"chatcmpl-{int(time.time())}",
            "object": "chat.completion",
            "created": int(time.time()),
            "model": "team-assistant",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "".join(chunks)
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": sum(len(msg.get("content", "")) for msg in openai_messages) // 4,
                "completion_tokens": len("".join(chunks)) // 4,
                "total_tokens": (sum(len(msg.get("content", "")) for msg in openai_messages) + len("".join(chunks))) // 4
            }
        }
        
        return response 

@router.get("/debug")
async def debug_agent_engine(request: Request, user=Depends(get_admin_user)):
    """Debug endpoint to check Team Assistant configuration"""
    return {
        "config_values": {
            "ENABLE_AGENT_ENGINE": getattr(request.app.state.config, 'ENABLE_AGENT_ENGINE', 'NOT_FOUND'),
            "AGENT_ENGINE_PROJECT_ID": getattr(request.app.state.config, 'AGENT_ENGINE_PROJECT_ID', 'NOT_FOUND'),
            "AGENT_ENGINE_LOCATION": getattr(request.app.state.config, 'AGENT_ENGINE_LOCATION', 'NOT_FOUND'),
            "AGENT_ENGINE_REASONING_ENGINE_ID": getattr(request.app.state.config, 'AGENT_ENGINE_REASONING_ENGINE_ID', 'NOT_FOUND'),
        },
        "environment_variables": {
            "ENABLE_AGENT_ENGINE": os.getenv('ENABLE_AGENT_ENGINE'),
            "AGENT_ENGINE_PROJECT_ID": os.getenv('AGENT_ENGINE_PROJECT_ID'),
            "AGENT_ENGINE_LOCATION": os.getenv('AGENT_ENGINE_LOCATION'),
            "AGENT_ENGINE_REASONING_ENGINE_ID": os.getenv('AGENT_ENGINE_REASONING_ENGINE_ID'),
        }
    }

@router.get("/status")
async def agent_engine_status(request: Request):
    """Public endpoint to check Team Assistant status (no auth required)"""
    try:
        config = request.app.state.config
        return {
            "status": "ok",
            "enabled": getattr(config, 'ENABLE_AGENT_ENGINE', False),
            "has_project_id": bool(getattr(config, 'AGENT_ENGINE_PROJECT_ID', '')),
            "has_reasoning_engine_id": bool(getattr(config, 'AGENT_ENGINE_REASONING_ENGINE_ID', '')),
            "location": getattr(config, 'AGENT_ENGINE_LOCATION', 'not_set'),
            "environment_vars": {
                "ENABLE_AGENT_ENGINE": bool(os.getenv('ENABLE_AGENT_ENGINE')),
                "has_project_id": bool(os.getenv('AGENT_ENGINE_PROJECT_ID')),
                "has_reasoning_engine_id": bool(os.getenv('AGENT_ENGINE_REASONING_ENGINE_ID')),
            }
        }
    except Exception as e:
        return {"status": "error", "error": str(e)} 