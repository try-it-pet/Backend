import os


class Settings:
    """환경 변수 기반 설정. 프로바이더 교체는 PETFIT_PROVIDER 로."""

    provider: str = os.getenv("PETFIT_PROVIDER", "mock")  # mock | (추후) real
    # 실제 모델 연결 시 사용할 값들 (mock 단계에선 비어 있음)
    model_api_key: str = os.getenv("PETFIT_MODEL_API_KEY", "")
    model_base_url: str = os.getenv("PETFIT_MODEL_BASE_URL", "")
    cors_origins: list[str] = (
        os.getenv("PETFIT_CORS_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173").split(",")
    )


settings = Settings()
