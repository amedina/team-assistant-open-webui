# Open WebUI Architecture Analysis for Agent Engine Integration

## Objective
This document provides a comprehensive architectural analysis of this Open WebUI fork to understand how to integrate it with a custom agent running on Agent Engine.

## Executive Summary

Open WebUI is a sophisticated, modular chat application built with FastAPI (backend) and SvelteKit (frontend) that provides a flexible abstraction layer for multiple AI providers. The architecture is designed around **provider patterns** where OpenAI-compatible APIs, Ollama, and custom functions/pipelines can be seamlessly integrated.

For your Agent Engine integration, the **OpenAI provider pattern** is the most suitable approach, requiring minimal code changes while providing full feature compatibility including streaming responses, authentication, and metadata handling.

The integration is highly feasible through the existing **OPENAI_API_BASE_URLS** configuration system, where your Agent Engine would appear as another "OpenAI-compatible" provider.

## 1. Architecture Overview

### Component Structure

The system follows a three-tier architecture:

1. **Frontend (SvelteKit)** - User interface and client-side logic
2. **Backend (FastAPI)** - API layer and business logic
3. **Provider Layer** - External AI service integrations

### Key Components

- **Chat Interface** (`src/lib/components/chat/`)
- **Admin Settings** (`src/lib/components/admin/`)
- **API Clients** (`src/lib/apis/`)
- **Streaming Handler** (`src/lib/apis/streaming/index.ts`)
- **OpenAI Router** (`backend/open_webui/routers/openai.py`) - **TARGET FOR INTEGRATION**
- **Configuration Management** (`backend/open_webui/config.py`)

## 2. Provider Integration Pattern

### Current Multi-Provider Setup

```python
# Configuration arrays for multiple providers
OPENAI_API_BASE_URLS = ["https://api.openai.com/v1", "https://custom-provider.com/v1"]
OPENAI_API_KEYS = ["sk-...", "custom-key"]
OPENAI_API_CONFIGS = {
    "0": {"enable": True, "model_ids": []},
    "1": {"enable": True, "prefix_id": "custom", "tags": ["custom"]}
}
```

### Core API Endpoints

- `/api/chat/completions` - Main chat completion endpoint
- `/api/models` - Model listing and discovery
- `/openai/config` - Provider configuration management

## 3. Agent Engine Integration Strategy

### Recommended Approach: OpenAI Provider Pattern

This leverages existing infrastructure with minimal changes:

1. **Configuration Setup:**
   ```python
   OPENAI_API_BASE_URLS.append("https://us-central1-aiplatform.googleapis.com/v1/projects/ps-agent-sandbox/locations/us-central1/reasoningEngines/5679434954300194816")
   OPENAI_API_KEYS.append("service-account-token")
   ```

2. **Authentication Adaptation:**
   - Replace `gcloud auth print-access-token` with service account authentication
   - Implement token refresh logic
   - Add custom headers in the OpenAI router

3. **Request Transformation:**
   - Convert OpenWebUI message format to Agent Engine format
   - Handle the `streamQuery` endpoint requirement

4. **Response Processing:**
   - Parse SSE responses and extract crew metadata
   - Convert to OpenAI-compatible streaming format

### Key Integration Points

**Backend Files to Modify:**
- `backend/open_webui/routers/openai.py` - Main integration point
- `backend/open_webui/config.py` - Configuration updates

**Frontend Integration:**
- `src/lib/apis/streaming/index.ts` - Streaming response handling
- Chat components for crew metadata display

## 4. Implementation Roadmap

### Phase 1: Basic Integration (Week 1-2)

**Authentication Setup:**
- Create GCP service account
- Implement token refresh mechanism
- Test API access

**Configuration:**
- Add Agent Engine URL to provider list
- Configure authentication tokens
- Test configuration loading

**Request Pipeline:**
- Modify OpenAI router to detect Agent Engine URLs
- Transform request format for `streamQuery` endpoint
- Implement basic request forwarding

### Phase 2: Streaming & Metadata (Week 3-4)

**Streaming Response Handling:**
- Parse Agent Engine SSE format
- Convert `routing_info` and `final_result` to OpenAI chunks
- Ensure proper streaming termination

**Crew Metadata Integration:**
- Extract crew routing information
- Store crew data in message metadata
- Implement metadata display logic

### Phase 3: Polish & Optimization (Week 5-6)

**Frontend Enhancements:**
- Show crew selection in chat interface
- Add Agent Engine provider indicators
- Update admin configuration UI

**Performance & Monitoring:**
- Cache service account tokens
- Add monitoring and logging
- Implement connection pooling

## 5. Code Implementation Guide

### Authentication Implementation

```python
# In openai.py, modify request headers:
async def send_agent_engine_request(url, payload, key):
    headers = {
        "Authorization": f"Bearer {service_account_token}",
        "Content-Type": "application/json"
    }
    agent_payload = {
        "class_method": "stream_query", 
        "input": {"input": {"messages": payload["messages"]}}
    }
```

### Message Format Conversion

```python
# Convert OpenWebUI messages to Agent Engine format
def convert_messages_to_agent_engine(messages):
    return [
        {
            "type": "human" if msg["role"] == "user" else "ai",
            "content": msg["content"]
        }
        for msg in messages
    ]
```

### Response Format Conversion

```python
# Convert Agent Engine SSE to OpenAI format
async def convert_agent_engine_response(line):
    data = json.loads(line.replace("data: ", ""))
    
    if data.get("type") == "routing_info":
        return {
            "choices": [{"delta": {"content": ""}}],
            "metadata": {
                "crew_selected": data["crew_selected"],
                "crew_description": data["crew_description"]
            }
        }
    elif data.get("type") == "final_result":
        return {
            "choices": [{"delta": {"content": data["content"]}}],
            "metadata": {"crew_used": data["crew_used"]}
        }
```

## 6. Action Items

### Immediate Next Steps

1. **Set up GCP Service Account:**
   ```bash
   gcloud iam service-accounts create openwebui-agent-engine
   gcloud projects add-iam-policy-binding ps-agent-sandbox \
     --member="serviceAccount:openwebui-agent-engine@ps-agent-sandbox.iam.gserviceaccount.com" \
     --role="roles/aiplatform.user"
   ```

2. **Test Agent Engine API Access:**
   ```bash
   curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        https://us-central1-aiplatform.googleapis.com/v1/projects/ps-agent-sandbox/locations/us-central1/reasoningEngines/5679434954300194816:streamQuery?alt=sse \
        -d '{"class_method": "stream_query","input": {"input": {"messages": [{"type": "human","content": "Hello"}]}}}'
   ```

3. **Modify OpenAI Router:**
   ```python
   # In backend/open_webui/routers/openai.py
   if "aiplatform.googleapis.com" in url:
       return await handle_agent_engine_request(url, payload, key, user)
   ```

4. **Create Development Branch:**
   ```bash
   git checkout -b feature/agent-engine-integration
   ```

### Implementation Priority

**High Priority:**
- Service account authentication setup
- Basic request/response transformation
- OpenAI router modification for Agent Engine detection
- Streaming response parsing

**Medium Priority:**
- Crew metadata extraction and display
- Error handling and retry logic
- Admin configuration interface

**Low Priority:**
- Performance optimizations
- Advanced crew management features
- Detailed monitoring and analytics

## 7. Feature Compatibility

### Core Features Maintained
- ✅ Streaming responses
- ✅ Message history
- ✅ User authentication
- ✅ Model selection
- ✅ Response formatting
- ✅ Error handling

### Agent Engine Specific Features
- ✅ Crew routing information
- ✅ Crew selection metadata
- ✅ GCP authentication
- ⚠️ Tool calling (may need adaptation)
- ⚠️ Function calling (may need adaptation)

## 8. Conclusion

This integration approach leverages Open WebUI's existing provider architecture, ensuring compatibility with all existing features while providing a clean separation of concerns for your Agent Engine integration. The recommended OpenAI provider pattern approach minimizes risk while maximizing feature compatibility.

**Key Success Factors:**
- **Minimal Code Changes**: Using existing provider patterns
- **Preserved Functionality**: Maintaining all current Open WebUI features
- **Enhanced Capabilities**: Adding crew routing and metadata display
- **Production Readiness**: Proper error handling, authentication, and monitoring

The integration is technically straightforward and aligns well with Open WebUI's architectural patterns, making it a low-risk, high-value enhancement to the platform. 