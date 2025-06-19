#!/usr/bin/env python3
import sys
import os
import asyncio
from unittest.mock import MagicMock

# Add the backend directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

async def test_model_name():
    try:
        from open_webui.routers.agent_engine import get_agent_engine_models_public
        
        # Mock request object
        request = MagicMock()
        request.app.state.config.ENABLE_AGENT_ENGINE = True
        
        result = await get_agent_engine_models_public(request)
        print('Test Results:')
        print('=' * 50)
        
        if result['data']:
            model = result['data'][0]
            print(f'✅ Model ID: {model["id"]}')
            print(f'✅ Model Name: {model["name"]}')
            print(f'✅ Model Owner: {model["owned_by"]}')
            print(f'✅ Description: {model["info"]["meta"]["description"]}')
            print(f'✅ Message: {result.get("message", "N/A")}')
            
            # Verify the changes
            assert model["id"] == "team-assistant", f"Expected 'team-assistant', got '{model['id']}'"
            assert model["name"] == "Team Assistant", f"Expected 'Team Assistant', got '{model['name']}'"
            assert model["owned_by"] == "team-assistant", f"Expected 'team-assistant', got '{model['owned_by']}'"
            assert "Team Assistant" in model["info"]["meta"]["description"]
            
            print('\n🎉 All tests passed! Model has been successfully renamed to "Team Assistant"')
        else:
            print('❌ No models returned')
            
    except Exception as e:
        print(f'❌ Test failed: {e}')
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_model_name()) 