# Agent Engine Implementation Guide

## Overview
This guide addresses your specific implementation questions for integrating Agent Engine with Open WebUI using a dedicated router approach.

## 1. Single Model Registration

Instead of multiple crew-specific models, register one main Agent Engine model:

```python
# backend/open_webui/utils/agent_engine.py
def register_agent_engine_models():
    return [{
        "id": "agent-engine",
        "name": "Agent Engine", 
        "owned_by": "agent_engine",
        "object": "model",
        "created": int(time.time()),
        "info": {
            "meta": {
                "description": "AI Agent with intelligent crew routing",
                "capabilities": {
                    "streaming": True,
                    "crew_routing": True,
                    "metadata": True
                }
            }
        }
    }]
```

## 2. Multi-Part Response Handling

Your Agent Engine returns:
- Part 1: `{"type": "routing_info", "crew_selected": "poem_crew", ...}`
- Part 2+: `{"type": "final_result", "content": "...", "crew_used": "..."}`

Implementation:

```python
async def stream_agent_engine_response(agent_request, credentials, project_id, location, reasoning_engine_id):
    crew_info_sent = False
    
    async for line in response.content:
        agent_data = json.loads(line[6:])  # Remove 'data: '
        
        if agent_data.get("type") == "routing_info":
            # Show crew selection to user
            openai_response = {
                "choices": [{"delta": {"content": ""}}],
                "agent_metadata": {
                    "type": "routing_info",
                    "crew_selected": agent_data.get("crew_selected"),
                    "crew_description": agent_data.get("crew_description")
                }
            }
            yield f"data: {json.dumps(openai_response)}\\n\\n"
            
        elif agent_data.get("type") == "final_result":
            # Stream actual content
            openai_response = {
                "choices": [{"delta": {"content": agent_data.get("content")}}],
                "agent_metadata": {"crew_used": agent_data.get("crew_used")}
            }
            yield f"data: {json.dumps(openai_response)}\\n\\n"
```

## 3. Service Account Configuration

### 3.1 Passing Service Account Information

**Option A: Environment Variable (Recommended)**
```bash
export AGENT_ENGINE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

**Option B: Admin UI Configuration**
Add to config.py:
```python
AGENT_ENGINE_SERVICE_ACCOUNT_JSON = PersistentConfig(
    "AGENT_ENGINE_SERVICE_ACCOUNT_JSON",
    "agent_engine.service_account_json", 
    os.environ.get("AGENT_ENGINE_SERVICE_ACCOUNT_JSON", "")
)
```

**Authentication Helper:**
```python
def get_agent_engine_credentials():
    service_account_json = AGENT_ENGINE_SERVICE_ACCOUNT_JSON.value
    if service_account_json:
        credentials_info = json.loads(service_account_json)
        return service_account.Credentials.from_service_account_info(
            credentials_info,
            scopes=['https://www.googleapis.com/auth/cloud-platform']
        )
    # Fallback to default credentials
    return default(scopes=['https://www.googleapis.com/auth/cloud-platform'])[0]
```

### 3.2 User Interface Experience

**For End Users:**
1. Select "Agent Engine" from model dropdown
2. Chat normally - crew routing is automatic
3. See crew information displayed transparently
4. No need to understand Agent Engine internals

**For Administrators:**
Configure once in admin panel:
- Project ID: `ps-agent-sandbox`
- Location: `us-central1` 
- Reasoning Engine ID: `5679434954300194816`
- Service Account JSON: Paste full JSON

**Admin UI Component:**
```svelte
<!-- Agent Engine Configuration Panel -->
<div class="agent-engine-config">
    <h3>Agent Engine Integration</h3>
    
    <input bind:value={config.AGENT_ENGINE_PROJECT_ID} 
           placeholder="Project ID" />
    
    <select bind:value={config.AGENT_ENGINE_LOCATION}>
        <option value="us-central1">us-central1</option>
    </select>
    
    <input bind:value={config.AGENT_ENGINE_REASONING_ENGINE_ID}
           placeholder="Reasoning Engine ID" />
    
    <textarea bind:value={config.AGENT_ENGINE_SERVICE_ACCOUNT_JSON}
              placeholder="Service Account JSON"
              rows="6"></textarea>
              
    <button on:click={saveConfig}>Save Configuration</button>
</div>
```

**Crew Information Display:**
```svelte
<!-- Show crew routing info to users -->
{#if metadata?.type === 'routing_info'}
    <div class="crew-info bg-blue-50 p-3 rounded">
        <span class="text-blue-700">🤖 Crew: {metadata.crew_selected}</span>
        <p class="text-sm">{metadata.crew_description}</p>
    </div>
{/if}
```

## Implementation Steps

1. **Add Configuration** - Update config.py with Agent Engine settings
2. **Create Router** - Implement `/backend/open_webui/routers/agent_engine.py`
3. **Register Routes** - Add router to main.py
4. **Update Frontend** - Add admin UI for configuration
5. **Handle Responses** - Update chat UI to show crew information
6. **Test Integration** - Verify streaming and authentication work

This approach provides a seamless experience where users interact with one "Agent Engine" model, while the system handles crew routing and displays relevant information automatically. 