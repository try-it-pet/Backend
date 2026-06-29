from typing import Optional

from ..config import settings
from .base import ProviderOutput, TryOnProvider
from .mock import MockProvider
from .openai_provider import OpenAIProvider
from .replicate_provider import ReplicateProvider

__all__ = ["TryOnProvider", "ProviderOutput", "get_provider", "PROVIDERS"]

PROVIDERS = ("mock", "openai", "replicate")


def get_provider(name: Optional[str] = None) -> TryOnProvider:
    """이름으로 프로바이더 반환. None 이면 기본값(settings.provider).

    요청별 override 를 지원해 같은 입력으로 mock/openai/replicate 를 비교할 수 있다.
    """
    key = (name or settings.provider).lower()
    if key == "mock":
        return MockProvider()
    if key in ("openai", "gpt-image-1"):
        return OpenAIProvider()
    if key in ("replicate", "real"):
        return ReplicateProvider()
    raise ValueError(f"unknown provider: {key}")
