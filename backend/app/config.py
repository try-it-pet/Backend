import os
from pathlib import Path

try:  # .env 를 앱에서 직접 로드(uvicorn --env-file + --reload 전달 누락 대비)
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
except ImportError:
    pass


class Settings:
    """환경 변수 기반 설정. 프로바이더는 요청별 override 또는 기본값(PETFIT_PROVIDER)."""

    # 기본 프로바이더: mock | openai | replicate
    provider: str = os.getenv("PETFIT_PROVIDER", "mock")

    # OpenAI (gpt-image-2, 2026-04 출시 — 편집·지시이해·2K 향상)
    openai_api_key: str = os.getenv("PETFIT_OPENAI_API_KEY", "")
    openai_model: str = os.getenv("PETFIT_OPENAI_MODEL", "gpt-image-2")
    # 펫(강아지/고양이) 판별용 비전 모델 — 생성 전 사진 사전 검증
    vision_model: str = os.getenv("PETFIT_VISION_MODEL", "gpt-4o-mini")
    # size: 양 변 16의 배수, 최대 변 3840px, 총 픽셀 655,360~8,294,400
    openai_size: str = os.getenv("PETFIT_OPENAI_SIZE", "1024x1024")

    # Replicate
    replicate_token: str = os.getenv("PETFIT_REPLICATE_TOKEN", "")
    # 이미지 편집 모델(레퍼런스 이미지 + 프롬프트). 모델/버전은 env 로 교체.
    # LoRA 파인튜닝을 쓰려면 오픈웨이트 dev 버전이어야 함(pro 는 폐쇄형 = LoRA 불가).
    replicate_model: str = os.getenv("PETFIT_REPLICATE_MODEL", "black-forest-labs/flux-kontext-dev")
    # 감성 룩 → 학습된 LoRA 모델 매핑(JSON). 예: {"winter":"ljo1010/pawdy-winter:<ver>"}
    look_models_json: str = os.getenv("PETFIT_LOOK_MODELS", "")
    # 룩 → LoRA 트리거 단어 매핑(JSON, 선택). 예: {"winter":"PAWDYWINTER"}
    look_triggers_json: str = os.getenv("PETFIT_LOOK_TRIGGERS", "")
    # LoRA 학습 대상(트레이너 모델 버전) — scripts/train_lora.py 에서 사용
    replicate_trainer: str = os.getenv(
        "PETFIT_REPLICATE_TRAINER", "replicate/fast-flux-trainer:latest"
    )

    # 인증 (JWT + Kakao OAuth)
    jwt_secret: str = os.getenv("PETFIT_JWT_SECRET", "dev-secret-change-me")
    jwt_expire_days: int = int(os.getenv("PETFIT_JWT_EXPIRE_DAYS", "30"))
    kakao_rest_api_key: str = os.getenv("PETFIT_KAKAO_REST_API_KEY", "")
    kakao_redirect_uri: str = os.getenv(
        "PETFIT_KAKAO_REDIRECT_URI", "http://localhost:8000/auth/kakao/callback"
    )
    frontend_url: str = os.getenv("PETFIT_FRONTEND_URL", "http://localhost:5173")
    # dev-login(키 없이 테스트) 허용 여부 — 운영에선 false 로
    allow_dev_login: bool = os.getenv("PETFIT_ALLOW_DEV_LOGIN", "1") not in ("0", "false", "False")

    cors_origins: list[str] = (
        os.getenv("PETFIT_CORS_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173").split(",")
    )

    def configured_providers(self) -> dict[str, bool]:
        return {
            "mock": True,
            "openai": bool(self.openai_api_key),
            "replicate": bool(self.replicate_token),
        }


settings = Settings()
