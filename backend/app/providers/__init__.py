from ..config import settings
from .base import TryOnProvider
from .mock import MockProvider


def get_provider() -> TryOnProvider:
    """설정에 따라 피팅 프로바이더를 반환. 실제 모델 추가 시 분기만 늘리면 됨."""
    if settings.provider == "mock":
        return MockProvider()
    # if settings.provider == "real":
    #     return RealProvider(api_key=settings.model_api_key, base_url=settings.model_base_url)
    raise ValueError(f"unknown provider: {settings.provider}")
