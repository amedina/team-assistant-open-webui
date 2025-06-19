# Agent Engine Single Model Implementation Guide

## 1. Single Model Registration

Instead of multiple crew-specific models, register one main Agent Engine model:

```python
# backend/open_webui/utils/agent_engine.py
def register_agent_engine_models():
    """Register a single Agent Engine model that handles internal crew routing"""
    return [
        {
            "id": "agent-engine",
            "name": "Agent Engine",
            "owned_by": "agent_engine",
            "object": "model",
            "created": int(time.time()),
            "info": {
                "meta": {
                    "description": "AI Agent with intelligent crew routing for diverse tasks",
                    "profile_image_url": "/static/agent-engine-logo.png",  # Optional custom logo
                    "capabilities": {
                        "streaming": True,
                        "crew_routing": True,
                        "metadata": True,
                        "multi_crew": True
                    },
                    "tags": [
                        {"name": "reasoning"},
                        {"name": "multi-crew"},
                        {"name": "gcp"}
                    ]
                }
            }
        }
    ]
```

## 2. Multi-Part Response Handling

Your Agent Engine returns two types of responses that need different handling:

### Response Type 1: Routing Information
```json
{
    "type": "routing_info", 
    "crew_selected": "poem_crew", 
    "crew_description": "Creative crew for crafting delightful poetry about AI assistance",
    "query": "Write me a poem"
}
```

### Response Type 2: Final Result
```json
{
    "type": "final_result",
    "content": "DevRel's new pal? An AI so grand...",
    "crew_used": "poem_crew"
}
```

### Implementation in Agent Engine Router

```python
# backend/open_webui/routers/agent_engine.py
import json
import aiohttp
import asyncio
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from google.auth import default
from google.auth.transport.requests import Request as GoogleRequest

router = APIRouter()

async def stream_agent_engine_response(agent_request, credentials, project_id, location, reasoning_engine_id):
    """Handle streaming response from Agent Engine with multi-part processing"""
    
    # Get access token
    credentials.refresh(GoogleRequest())
    access_token = credentials.token
    
    # Construct Agent Engine URL
    api_endpoint = f"https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/reasoningEngines/{reasoning_engine_id}:streamQuery?alt=sse"
    
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    
    async with aiohttp.ClientSession() as session:
        async with session.post(api_endpoint, json=agent_request, headers=headers) as response:
            if response.status != 200:
                error_text = await response.text()
                yield f"data: {json.dumps({'error': {'message': f'Agent Engine error: {error_text}'}})}\n\n"
                return
            
            crew_info_sent = False
            
            async for line in response.content:
                line = line.decode('utf-8').strip()
                
                if not line or not line.startswith('data: '):
                    continue
                
                # Remove 'data: ' prefix
                json_str = line[6:]
                
                try:
                    agent_data = json.loads(json_str)
                    
                    if agent_data.get("type") == "routing_info":
                        # Handle routing information - show crew selection
                        if not crew_info_sent:
                            openai_response = {
                                "choices": [{
                                    "delta": {"content": ""},
                                    "index": 0,
                                    "finish_reason": None
                                }],
                                "agent_metadata": {
                                    "type": "routing_info",
                                    "crew_selected": agent_data.get("crew_selected"),
                                    "crew_description": agent_data.get("crew_description"),
                                    "query": agent_data.get("query")
                                }
                            }
                            yield f"data: {json.dumps(openai_response)}\n\n"
                            crew_info_sent = True
                    
                    elif agent_data.get("type") == "final_result":
                        # Handle final result - stream content
                        content = agent_data.get("content", "")
                        crew_used = agent_data.get("crew_used", "")
                        
                        # Send the actual content
                        openai_response = {
                            "choices": [{
                                "delta": {"content": content},
                                "index": 0,
                                "finish_reason": None
                            }],
                            "agent_metadata": {
                                "type": "final_result",
                                "crew_used": crew_used
                            }
                        }
                        yield f"data: {json.dumps(openai_response)}\n\n"
                        
                        # Send completion marker
                        completion_response = {
                            "choices": [{
                                "delta": {},
                                "index": 0,
                                "finish_reason": "stop"
                            }]
                        }
                        yield f"data: {json.dumps(completion_response)}\n\n"
                        yield "data: [DONE]\n\n"
                        return
                
                except json.JSONDecodeError:
                    # Handle non-JSON lines
                    continue
                except Exception as e:
                    error_response = {
                        "choices": [{
                            "delta": {},
                            "index": 0,
                            "finish_reason": "error"
                        }],
                        "error": {"message": f"Processing error: {str(e)}"}
                    }
                    yield f"data: {json.dumps(error_response)}\n\n"
                    return

@router.post("/chat/completions")
async def generate_chat_completion(
    request: Request,
    form_data: dict,
    user=Depends(get_verified_user),
):
    """Generate chat completion using Agent Engine"""
    
    # Get configuration
    project_id = request.app.state.config.AGENT_ENGINE_PROJECT_ID.value
    location = request.app.state.config.AGENT_ENGINE_LOCATION.value
    reasoning_engine_id = request.app.state.config.AGENT_ENGINE_REASONING_ENGINE_ID.value
    
    if not all([project_id, location, reasoning_engine_id]):
        raise HTTPException(
            status_code=500,
            detail="Agent Engine not properly configured. Please check admin settings."
        )
    
    # Transform Open WebUI format to Agent Engine format
    messages = form_data.get("messages", [])
    agent_request = {
        "class_method": "stream_query",
        "input": {
            "input": {"messages": messages}
        }
    }
    
    # Get GCP credentials
    try:
        credentials = get_agent_engine_credentials()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Authentication error: {str(e)}"
        )
    
    if form_data.get("stream", True):
        return StreamingResponse(
            stream_agent_engine_response(agent_request, credentials, project_id, location, reasoning_engine_id),
            media_type="text/event-stream"
        )
    else:
        # Handle non-streaming case if needed
        raise HTTPException(
            status_code=400,
            detail="Non-streaming mode not yet implemented for Agent Engine"
        )
```

## 3. Service Account Configuration

### 3.1 How to Pass Service Account Information

You have several options for passing the service account:

#### Option A: Environment Variable (Recommended for Production)
```bash
# Set as environment variable
export AGENT_ENGINE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"ps-agent-sandbox",...}'
```

#### Option B: File Path (Alternative)
```bash
# Set path to service account file
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

#### Option C: Admin UI Configuration (Most User-Friendly)
Add to the admin configuration interface:

```python
# backend/open_webui/config.py - Add these configurations
ENABLE_AGENT_ENGINE = PersistentConfig(
    "ENABLE_AGENT_ENGINE",
    "agent_engine.enable",
    os.environ.get("ENABLE_AGENT_ENGINE", "False").lower() == "true",
)

AGENT_ENGINE_PROJECT_ID = PersistentConfig(
    "AGENT_ENGINE_PROJECT_ID",
    "agent_engine.project_id",
    os.environ.get("AGENT_ENGINE_PROJECT_ID", ""),
)

AGENT_ENGINE_LOCATION = PersistentConfig(
    "AGENT_ENGINE_LOCATION",
    "agent_engine.location", 
    os.environ.get("AGENT_ENGINE_LOCATION", "us-central1"),
)

AGENT_ENGINE_REASONING_ENGINE_ID = PersistentConfig(
    "AGENT_ENGINE_REASONING_ENGINE_ID",
    "agent_engine.reasoning_engine_id",
    os.environ.get("AGENT_ENGINE_REASONING_ENGINE_ID", ""),
)

AGENT_ENGINE_SERVICE_ACCOUNT_JSON = PersistentConfig(
    "AGENT_ENGINE_SERVICE_ACCOUNT_JSON",
    "agent_engine.service_account_json",
    os.environ.get("AGENT_ENGINE_SERVICE_ACCOUNT_JSON", ""),
)
```

### Authentication Helper Function
```python
# backend/open_webui/utils/agent_engine.py
import json
from google.auth import default
from google.oauth2 import service_account

def get_agent_engine_credentials():
    """Get GCP credentials for Agent Engine authentication"""
    
    # Try service account JSON first
    service_account_json = AGENT_ENGINE_SERVICE_ACCOUNT_JSON.value
    if service_account_json:
        try:
            credentials_info = json.loads(service_account_json)
            credentials = service_account.Credentials.from_service_account_info(
                credentials_info,
                scopes=['https://www.googleapis.com/auth/cloud-platform']
            )
            return credentials
        except json.JSONDecodeError:
            raise Exception("Invalid service account JSON format")
        except Exception as e:
            raise Exception(f"Service account authentication failed: {str(e)}")
    
    # Fallback to default credentials (for local development)
    try:
        credentials, project = default(
            scopes=['https://www.googleapis.com/auth/cloud-platform']
        )
        return credentials
    except Exception as e:
        raise Exception(f"Default authentication failed: {str(e)}")
```

### 3.2 How Users Would Use the Open WebUI Interface

Users interact with Agent Engine through the standard Open WebUI interface:

#### For End Users:
1. **Model Selection**: Users see "Agent Engine" in the model dropdown
2. **Chat Interface**: Users chat normally - no special Agent Engine knowledge needed
3. **Crew Information**: Users see crew selection info automatically displayed
4. **Seamless Experience**: All Agent Engine complexity is hidden

#### For Administrators:
1. **Admin Panel Configuration**:

```python
# Add to admin settings UI
# backend/open_webui/routers/agent_engine.py
@router.get("/config")
async def get_config(request: Request, user=Depends(get_admin_user)):
    return {
        "ENABLE_AGENT_ENGINE": request.app.state.config.ENABLE_AGENT_ENGINE.value,
        "AGENT_ENGINE_PROJECT_ID": request.app.state.config.AGENT_ENGINE_PROJECT_ID.value,
        "AGENT_ENGINE_LOCATION": request.app.state.config.AGENT_ENGINE_LOCATION.value,
        "AGENT_ENGINE_REASONING_ENGINE_ID": request.app.state.config.AGENT_ENGINE_REASONING_ENGINE_ID.value,
        # Don't expose the actual service account JSON for security
        "AGENT_ENGINE_CONFIGURED": bool(request.app.state.config.AGENT_ENGINE_SERVICE_ACCOUNT_JSON.value),
    }

@router.post("/config/update")
async def update_config(
    request: Request, 
    form_data: AgentEngineConfigForm, 
    user=Depends(get_admin_user)
):
    """Update Agent Engine configuration"""
    request.app.state.config.ENABLE_AGENT_ENGINE = form_data.ENABLE_AGENT_ENGINE
    request.app.state.config.AGENT_ENGINE_PROJECT_ID = form_data.AGENT_ENGINE_PROJECT_ID
    request.app.state.config.AGENT_ENGINE_LOCATION = form_data.AGENT_ENGINE_LOCATION
    request.app.state.config.AGENT_ENGINE_REASONING_ENGINE_ID = form_data.AGENT_ENGINE_REASONING_ENGINE_ID
    
    if form_data.AGENT_ENGINE_SERVICE_ACCOUNT_JSON:
        request.app.state.config.AGENT_ENGINE_SERVICE_ACCOUNT_JSON = form_data.AGENT_ENGINE_SERVICE_ACCOUNT_JSON
    
    return {"status": "success"}

class AgentEngineConfigForm(BaseModel):
    ENABLE_AGENT_ENGINE: Optional[bool] = None
    AGENT_ENGINE_PROJECT_ID: str
    AGENT_ENGINE_LOCATION: str
    AGENT_ENGINE_REASONING_ENGINE_ID: str
    AGENT_ENGINE_SERVICE_ACCOUNT_JSON: Optional[str] = None
```

2. **Admin UI Component**:

```svelte
<!-- src/lib/components/admin/Settings/AgentEngine.svelte -->
<script>
    import { toast } from 'svelte-sonner';
    import { getAgentEngineConfig, updateAgentEngineConfig } from '$lib/apis/agent_engine';
    
    let config = {
        ENABLE_AGENT_ENGINE: false,
        AGENT_ENGINE_PROJECT_ID: '',
        AGENT_ENGINE_LOCATION: 'us-central1',
        AGENT_ENGINE_REASONING_ENGINE_ID: '',
        AGENT_ENGINE_CONFIGURED: false
    };
    
    const submitHandler = async () => {
        const res = await updateAgentEngineConfig(localStorage.token, config);
        if (res) {
            toast.success('Agent Engine configuration saved successfully');
        }
    };
</script>

<div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
        <div>
            <h3 class="text-lg font-medium">Agent Engine Integration</h3>
            <p class="text-sm text-gray-600">Configure Google Cloud Agent Engine integration</p>
        </div>
        <Switch bind:state={config.ENABLE_AGENT_ENGINE} />
    </div>
    
    {#if config.ENABLE_AGENT_ENGINE}
        <div class="space-y-4">
            <div>
                <label class="block text-sm font-medium mb-1">Project ID</label>
                <input 
                    type="text" 
                    bind:value={config.AGENT_ENGINE_PROJECT_ID}
                    placeholder="ps-agent-sandbox"
                    class="w-full p-2 border rounded"
                />
            </div>
            
            <div>
                <label class="block text-sm font-medium mb-1">Location</label>
                <select bind:value={config.AGENT_ENGINE_LOCATION} class="w-full p-2 border rounded">
                    <option value="us-central1">us-central1</option>
                    <option value="us-east1">us-east1</option>
                    <option value="europe-west1">europe-west1</option>
                </select>
            </div>
            
            <div>
                <label class="block text-sm font-medium mb-1">Reasoning Engine ID</label>
                <input 
                    type="text" 
                    bind:value={config.AGENT_ENGINE_REASONING_ENGINE_ID}
                    placeholder="5679434954300194816"
                    class="w-full p-2 border rounded"
                />
            </div>
            
            <div>
                <label class="block text-sm font-medium mb-1">Service Account JSON</label>
                <textarea 
                    bind:value={config.AGENT_ENGINE_SERVICE_ACCOUNT_JSON}
                    placeholder="Paste your service account JSON here..."
                    rows="6"
                    class="w-full p-2 border rounded font-mono text-xs"
                ></textarea>
                <p class="text-xs text-gray-500 mt-1">
                    Alternatively, set the AGENT_ENGINE_SERVICE_ACCOUNT_JSON environment variable
                </p>
            </div>
            
            <button 
                on:click={submitHandler}
                class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
                Save Configuration
            </button>
        </div>
    {/if}
</div>
```

## UI Enhancement for Crew Information

Update the chat interface to show crew information:

```svelte
<!-- src/lib/components/chat/Messages/AgentEngineInfo.svelte -->
<script>
    export let metadata;
</script>

{#if metadata?.type === 'routing_info'}
    <div class="agent-engine-routing bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 p-3 rounded-lg mb-3 border-l-4 border-blue-500">
        <div class="flex items-center gap-2 mb-2">
            <div class="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
            <span class="text-blue-700 dark:text-blue-300 font-medium text-sm">
                🤖 Crew Selected: {metadata.crew_selected}
            </span>
        </div>
        <p class="text-sm text-gray-700 dark:text-gray-300">
            {metadata.crew_description}
        </p>
        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Processing: "{metadata.query}"
        </p>
    </div>
{:else if metadata?.type === 'final_result'}
    <div class="agent-engine-completion text-xs text-gray-500 dark:text-gray-400 mb-2">
        ✅ Completed by: {metadata.crew_used}
    </div>
{/if}
```

## Summary

This implementation provides:

1. **Single Model**: One "Agent Engine" model that handles all crew routing internally
2. **Multi-Part Response**: Proper handling of routing info + final result
3. **Flexible Authentication**: Multiple ways to configure service account
4. **User-Friendly Interface**: End users see crew info automatically, admins have full configuration control
5. **Security**: Service account details are handled securely and not exposed to end users

The key insight is that Agent Engine's crew complexity is handled transparently - users just see enhanced responses with crew information, while administrators configure the GCP integration once. 