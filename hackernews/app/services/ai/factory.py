from app.config import settings
from app.services.ai.base import AIProvider
from app.services.ai.mock_provider import MockAIProvider
from app.services.ai.openai_provider import OpenAIProvider


def get_ai_provider() -> AIProvider:
    provider = (settings.AI_PROVIDER or "mock").lower()
    if provider == "openai":
        return OpenAIProvider()
    return MockAIProvider()
