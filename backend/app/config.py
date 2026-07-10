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
    # 펫(강아지/고양이) 판별용 비전 모델 — 생성 전 사진 사전 검증.
    # OpenAI 탈피 → Replicate 경량 VLM(moondream2)로 주체를 설명받아 강아지/고양이 키워드 판별.
    pet_detect_model: str = os.getenv("PETFIT_PET_DETECT_MODEL", "lucataco/moondream2")
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
    # 룩 → LoRA 가중치 URL 매핑(JSON). flux-kontext-dev-lora 추론에 얹음.
    #   예: {"winter":"https://replicate.delivery/.../trained_model.tar"}
    look_loras_json: str = os.getenv("PETFIT_LOOK_LORAS", "")
    # 린 프롬프트(과지시 제거) 기준 튜닝값 1.0 — 학습된 시그니처 룩을 충분히 표현하면서도
    # 입력 펫 정체성이 잘 보존되는 지점(A/B: 0.8=정체성↑무드↓, 1.0=둘 다 균형).
    lora_strength: float = float(os.getenv("PETFIT_LORA_STRENGTH", "1.0"))
    # LoRA 추론 품질(프로덕션): 스텝·출력품질
    lora_steps: int = int(os.getenv("PETFIT_LORA_STEPS", "40"))
    lora_output_quality: int = int(os.getenv("PETFIT_LORA_OUTPUT_QUALITY", "100"))
    # Kontext guidance(프롬프트 준수 강도). 0=미전송(모델 기본값). 스키마 확실한 환경에서만 조정.
    lora_guidance: float = float(os.getenv("PETFIT_LORA_GUIDANCE", "0"))
    # LoRA 를 얹을 Kontext 편집 추론 모델
    kontext_lora_model: str = os.getenv(
        "PETFIT_KONTEXT_LORA_MODEL", "black-forest-labs/flux-kontext-dev-lora"
    )
    # 2단계 피팅: (1) multi-image 로 '실제 상품 옷' 착용 → (2) LoRA 로 시그니처 룩.
    # 실제 상품 옷(ref_image)이 있고 LoRA 룩일 때만 발동. 호출 2회·프리미엄 모델이라 비용↑ →
    # 끄려면 PETFIT_TWO_STAGE=0. multi-image 모델은 lora_weights 미지원(폐쇄형)이라 단계 분리.
    two_stage_fitting: bool = os.getenv("PETFIT_TWO_STAGE", "1") not in ("0", "false", "False")
    multi_image_model: str = os.getenv(
        "PETFIT_MULTI_IMAGE_MODEL", "flux-kontext-apps/multi-image-kontext-max"
    )
    # 출력 업스케일 후처리(Real-ESRGAN 등, Replicate). 해상도·디테일 ↑. 생성 비용/시간 증가로
    # 기본 off. 켜려면 PETFIT_UPSCALE=1 + PETFIT_REPLICATE_TOKEN 필요.
    upscale_enabled: bool = os.getenv("PETFIT_UPSCALE", "0") in ("1", "true", "True")
    upscale_model: str = os.getenv("PETFIT_UPSCALE_MODEL", "nightmareai/real-esrgan")
    upscale_factor: int = int(os.getenv("PETFIT_UPSCALE_FACTOR", "2"))
    # LoRA 학습 대상(Kontext 편집 트레이너) — scripts/train_lora.py 에서 사용
    replicate_trainer: str = os.getenv(
        "PETFIT_REPLICATE_TRAINER",
        "replicate/fast-flux-kontext-trainer:"
        "26c877b4ec3988b7e8edc5840e61339c68f09913bb11e23c31566590fd92a66d",
    )

    # Cloudflare R2 (S3 호환) — 생성 결과 이미지·LoRA 저장. 미설정 시 DB 폴백.
    r2_endpoint: str = os.getenv("PETFIT_R2_ENDPOINT", "")        # https://<account>.r2.cloudflarestorage.com
    r2_access_key: str = os.getenv("PETFIT_R2_ACCESS_KEY_ID", "")
    r2_secret_key: str = os.getenv("PETFIT_R2_SECRET_ACCESS_KEY", "")
    r2_bucket: str = os.getenv("PETFIT_R2_BUCKET", "")
    r2_public_base: str = os.getenv("PETFIT_R2_PUBLIC_BASE", "")  # https://pub-xxx.r2.dev 또는 커스텀 도메인

    def r2_configured(self) -> bool:
        return all([self.r2_endpoint, self.r2_access_key, self.r2_secret_key,
                    self.r2_bucket, self.r2_public_base])

    # 인증 (JWT + Kakao OAuth)
    jwt_secret: str = os.getenv("PETFIT_JWT_SECRET", "dev-secret-change-me")
    jwt_expire_days: int = int(os.getenv("PETFIT_JWT_EXPIRE_DAYS", "30"))
    kakao_rest_api_key: str = os.getenv("PETFIT_KAKAO_REST_API_KEY", "")
    # 신규 카카오 콘솔은 REST API 키 발급 시 클라이언트 시크릿 기본 활성화 — 토큰 교환 시 함께 전송
    kakao_client_secret: str = os.getenv("PETFIT_KAKAO_CLIENT_SECRET", "")
    kakao_redirect_uri: str = os.getenv(
        "PETFIT_KAKAO_REDIRECT_URI", "http://localhost:8000/auth/kakao/callback"
    )
    frontend_url: str = os.getenv("PETFIT_FRONTEND_URL", "http://localhost:5173")
    # dev-login(키 없이 테스트) 허용 여부 — 운영에선 false 로
    allow_dev_login: bool = os.getenv("PETFIT_ALLOW_DEV_LOGIN", "1") not in ("0", "false", "False")

    # 토스 페이먼츠 결제 연동 설정
    toss_secret_key: str = os.getenv("PETFIT_TOSS_SECRET_KEY", "")
    toss_client_key: str = os.getenv("PETFIT_TOSS_CLIENT_KEY", "")
    google_client_id: str = os.getenv("PETFIT_GOOGLE_CLIENT_ID", "")



    cors_origins: list[str] = (
        os.getenv("PETFIT_CORS_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173").split(",")
    )

    # AI 생성 횟수 제한(요금 방어). 극초반엔 무제한(gen_limit_enabled=False)으로 운영하다가,
    # 퀄리티 확신 생기면 켠다. 켜지면 계정당 free_generations 부여 + 구매 시 purchase_bonus 추가.
    gen_limit_enabled: bool = os.getenv("PETFIT_GEN_LIMIT", "0") in ("1", "true", "True")
    free_generations: int = int(os.getenv("PETFIT_FREE_GENERATIONS", "5"))
    purchase_bonus: int = int(os.getenv("PETFIT_PURCHASE_BONUS", "5"))
    # 인생네컷(4컷)이 소모하는 횟수 — 원가는 4배지만 UX상 기본 1회로 침(정책은 env로 조정).
    fourcut_cost: int = int(os.getenv("PETFIT_FOURCUT_COST", "1"))
    # 2단계 피팅(멀티이미지 착용 → LoRA 룩)이 소모하는 횟수 — 호출 2회+프리미엄이라 비용↑ → 기본 2회.
    two_stage_cost: int = int(os.getenv("PETFIT_TWO_STAGE_COST", "2"))
    # 전역 극초반 무제한 상한(누적 생성 이 수치 미만이면 제한 무시). 0 = 미사용.
    global_free_cap: int = int(os.getenv("PETFIT_GLOBAL_FREE_CAP", "0"))
    # 생성비 방어(요금 폭탄 차단). daily_gen_cap: 하루 전체 생성 상한(0=무제한, 초과 시 전면 차단).
    # ip_rate_per_min: 한 IP 가 분당 생성 요청 최대치(0=무제한).
    daily_gen_cap: int = int(os.getenv("PETFIT_DAILY_GEN_CAP", "0"))
    ip_rate_per_min: int = int(os.getenv("PETFIT_IP_RATE_PER_MIN", "10"))

    def configured_providers(self) -> dict[str, bool]:
        return {
            "mock": True,
            "openai": bool(self.openai_api_key),
            "replicate": bool(self.replicate_token),
        }


settings = Settings()
