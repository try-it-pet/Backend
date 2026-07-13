from typing import Optional

import anyio

from ..config import settings
from ..models import Pet, Product
from .base import ProviderOutput, TryOnProvider
from .looks import (
    BACKGROUND_PRESETS,
    COMPOSITION_PRESETS,
    FOURCUT_BOOTH,
    IDENTITY_LIGHT,
    IDENTITY_LOCK,
    ILLUSTRATION_LOOKS,
    LOOK_PROMPTS,
    LORA_FOURCUT_POSES,
    QUALITY_BOOST,
    SCENE_LOOKS,
    is_illustration,
    look_lora,
    look_model,
    look_trigger,
    two_stage_garment,
)
from .mock import recommend_size


def _build_prompt(
    product: Product,
    pet: Optional[Pet],
    style: Optional[str] = None,
    composition: Optional[str] = None,
    background: Optional[str] = None,
    trigger: Optional[str] = None,
    lora_active: bool = False,
) -> str:
    if is_illustration(style):  # 일러스트 룩: 옷 없이 펫을 다시 그림
        p = ILLUSTRATION_LOOKS[style]
        if composition in COMPOSITION_PRESETS:
            p += f" Pose: {COMPOSITION_PRESETS[composition]}."
        return p + " " + QUALITY_BOOST
    pet_desc = f"{pet.species}" if pet else "pet"

    # SCENE 룩 + 학습 LoRA(winter 등): 트리거가 학습된 '장면 전체 재연출'을 발동시키도록 프롬프트를
    # 짧고 트리거 우선으로 둔다. 긴 품질/정체성 꼬리(QUALITY_BOOST·IDENTITY_LOCK)를 붙이면 트리거가
    # 희석·매몰돼 장면 변환이 억제되고 원본이 거의 그대로 나온다(A/B로 확인). 선명도는 업스케일(#3)로 보완.
    if lora_active and trigger and style in SCENE_LOOKS:
        p = f"{trigger}. Dress this {pet_desc} in a {product.name} ({product.brand})."
        if composition in COMPOSITION_PRESETS:  # 인생네컷 포즈/표정 반영(정면·갸웃·활짝·얼빡)
            p += f" {COMPOSITION_PRESETS[composition]}."
        return p + f" {IDENTITY_LIGHT}"

    # 장면을 재연출하는 SCENE 룩이거나 인생네컷 포즈(fc_*, 포즈/표정을 바꿔야 함)면 "pose 유지"
    # 강제(IDENTITY_LOCK)를 쓰지 않는다 — 안 그러면 구도/표정이 안 바뀌어 4컷이 다 똑같아진다.
    allow_variation = (style in SCENE_LOOKS) or bool(composition and composition.startswith("fc_"))
    identity = IDENTITY_LIGHT if allow_variation else IDENTITY_LOCK
    base = (
        f"Dress this {pet_desc} in a {product.name} ({product.brand}), a piece of pet clothing. "
        f"Photorealistic, the garment fits naturally. {identity}"
    )
    extras: list[str] = []
    if trigger:  # LoRA 트리거 — 학습된 감성이 발동됨
        extras.append(f"{trigger} style.")
    # 학습된 LoRA 가 활성일 때는 룩 아트디렉션 대문단을 생략한다(과지시 방지). 폴백(LoRA 없음)일
    # 때만 프롬프트로 룩을 연출한다.
    if not lora_active and style in LOOK_PROMPTS:
        extras.append(f"Style: {LOOK_PROMPTS[style]}.")
    if composition in COMPOSITION_PRESETS:
        extras.append(f"Composition: {COMPOSITION_PRESETS[composition]}.")
    if style not in SCENE_LOOKS:
        extras.append(BACKGROUND_PRESETS.get(background or "studio", BACKGROUND_PRESETS["studio"]))
    extras.append(QUALITY_BOOST)
    return base + " " + " ".join(extras)


# 2단계 피팅 1단계(multi-image) 프롬프트: 실제 상품 옷을 몸에 입히고 좌우합성/플랫레이를 금지.
_WEAR_PROMPT = (
    "Photorealistic full-body photo of ONLY the pet from the first image. Completely REMOVE any "
    "clothing the pet is currently wearing, then dress it in the EXACT clothing item shown in the "
    "second image — replace its outfit entirely with that item, matching its exact colors, pattern, "
    "knit/fabric texture and every hood, collar, bandana and trim. Keep the pet's identity, face and "
    "fur. Clean soft studio background. Do NOT show the item separately, no flat-lay, no side-by-side, "
    "no collage, no mixing with the old outfit — a single subject wearing only the new item."
)


def _build_worn_prompt(
    style: Optional[str], composition: Optional[str], trigger: Optional[str],
) -> str:
    """이미 실제 옷을 입은 펫에 룩(장면)·포즈만 적용. 펫·옷은 그대로 보존한다.

    인생네컷: 실제 옷을 1번만 입히고(멀티이미지) 그 결과로 4컷을 파생시킬 때 각 컷의 프롬프트.
    """
    parts: list[str] = []
    if trigger:  # 학습 LoRA 룩 — 트리거가 장면을 발동
        parts.append(f"{trigger}.")
    elif style in LOOK_PROMPTS:  # 폴백 — 룩 아트디렉션으로 장면 연출
        parts.append(f"Style: {LOOK_PROMPTS[style]}.")
    if composition in COMPOSITION_PRESETS:  # 포즈/표정(정면·갸웃·활짝·얼빡 등)
        parts.append(f"{COMPOSITION_PRESETS[composition]}.")
    parts.append("Keep the exact same pet and the exact same outfit it is wearing.")
    parts.append(QUALITY_BOOST)
    return " ".join(parts)


def _rp_headers() -> tuple[str, dict]:
    tok = settings.replicate_token
    return tok, {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}


def _data_uri(data: bytes, mime: str = "image/png") -> str:
    import base64
    return f"data:{mime};base64," + base64.b64encode(data).decode()


def _version_of(model: str, tok: str) -> str:
    if ":" in model:  # owner/name:version
        return model.split(":", 1)[1]
    import replicate  # 공식 모델 슬러그 → 최신 버전
    return replicate.Client(api_token=tok).models.get(model).latest_version.id


def _predict(model: str, inp: dict, loops: int = 120) -> str:
    """Replicate 예측 생성 + 자체 폴링 → 출력 URL. (동기 — to_thread 로 호출)."""
    import time

    import httpx as hx

    tok, headers = _rp_headers()
    version = _version_of(model, tok)
    # 429 재시도: 크레딧 $5 미만이면 Replicate가 분당 6회·burst 1로 던지는데,
    # 2단계 피팅·인생네컷은 연속 호출이라 즉사한다 → Retry-After 만큼 기다렸다 재시도.
    r = None
    for _ in range(4):
        r = hx.post("https://api.replicate.com/v1/predictions", headers=headers,
                    json={"version": version, "input": inp}, timeout=60)
        if r.status_code != 429:
            break
        wait = int(r.headers.get("retry-after") or 10)
        time.sleep(min(wait + 1, 30))
    r.raise_for_status()
    pid = r.json()["id"]
    for _ in range(loops):  # 최대 ~6분 (콜드스타트 포함)
        time.sleep(3)
        s = hx.get(f"https://api.replicate.com/v1/predictions/{pid}",
                   headers=headers, timeout=30).json()
        st = s.get("status")
        if st == "succeeded":
            out = s.get("output")
            return str(out[0] if isinstance(out, list) else out)
        if st in ("failed", "canceled"):
            raise RuntimeError(s.get("error") or f"replicate {st}")
    raise RuntimeError("replicate 예측 시간 초과")


def _fetch_bytes(url: str) -> bytes:
    import httpx as hx
    return hx.get(url, timeout=120, follow_redirects=True).content


def _load_garment(product: Product) -> Optional[tuple[bytes, str]]:
    """상품 레퍼런스 옷 이미지 → (bytes, mime). 로컬 /static 또는 외부 URL. 실패 시 None."""
    from pathlib import Path
    ref = product.ref_image
    if not ref:
        return None
    try:
        if ref.startswith("/static/"):
            data = (Path(__file__).resolve().parent.parent / ref.lstrip("/")).read_bytes()
        else:
            import httpx as hx
            data = hx.get(ref, timeout=20, follow_redirects=True).content
        if not data:
            return None
        ext = Path(ref.split("?")[0]).suffix.lower().lstrip(".")
        return data, ("image/jpeg" if ext in ("jpg", "jpeg") else "image/png")
    except Exception:  # noqa: BLE001 — 옷 로드 실패 시 2단계 생략(펫만으로 진행)
        return None


class ReplicateProvider(TryOnProvider):
    """Replicate 호스팅 이미지 편집 모델(Flux Kontext)로 펫에 옷을 입힌다.

    감성 룩(style) 우선순위:
      1) PETFIT_LOOK_LORAS 에 LoRA 가중치 URL 등록 → flux-kontext-dev-lora 로 편집+LoRA 적용.
      2) PETFIT_LOOK_MODELS 에 학습 모델 ref → 그 모델로.
      3) 없으면 기본 편집 모델 + 룩 프롬프트 폴백.
    """

    name = "replicate"

    async def generate(
        self,
        *,
        product: Product,
        size: str,
        pet: Optional[Pet] = None,
        pet_image: Optional[bytes] = None,
        style: Optional[str] = None,
        composition: Optional[str] = None,
        background: Optional[str] = None,
        seed: Optional[int] = None,
        worn: bool = False,
    ) -> ProviderOutput:
        if not settings.replicate_token:
            raise RuntimeError("PETFIT_REPLICATE_TOKEN 가 설정되지 않았습니다.")
        if pet_image is None:
            raise RuntimeError("Replicate 프로바이더는 펫 이미지(pet_image)가 필요합니다.")
        try:
            import replicate
        except ImportError as exc:
            raise RuntimeError("replicate 패키지가 없습니다: pip install replicate") from exc

        rec = size or recommend_size(pet)
        pet_name = pet.name if pet else "반려동물"

        lora = look_lora(style)          # LoRA 가중치 URL (있으면 최우선)
        trained_model = look_model(style)  # 학습된 전체 모델 ref (LoRA 없을 때)
        trigger = look_trigger(style) if lora else None

        if worn:
            # 입력이 이미 실제 옷을 입은 상태(인생네컷: 옷을 1번만 입히고 컷을 파생) →
            # 옷 착용 단계 생략, 룩(장면)·포즈만 적용하고 펫·옷을 보존.
            garment = None
            two_stage = False
            stage2_prompt = _build_worn_prompt(style, composition, trigger)
        else:
            # 2단계 피팅: 실제 상품 옷(ref_image) + LoRA 룩이면, 먼저 multi-image 로 그 옷을 입힌 뒤
            # LoRA 로 시그니처 룩을 얹는다(무지옷 대신 실제 상품 반영). 없으면 단일 단계.
            # 인생네컷 포즈(fc_*)는 컷당 2배 호출이 되므로 여기선 제외(옷은 상위에서 1번만 입힘).
            is_fourcut = bool(composition) and composition.startswith("fc_")
            garment = _load_garment(product) if (
                two_stage_garment(style, bool(product.ref_image)) and not is_fourcut
            ) else None
            two_stage = garment is not None

            if two_stage:
                # 1단계에서 옷을 이미 입혔으므로 2단계는 펫+옷을 보존하며 룩만 연출.
                # LoRA 룩=트리거 우선(짧게, 희석 방지) / LoRA 없는 SCENE 룩=프롬프트로 장면 연출.
                stage2_prompt = (
                    f"{trigger}. Keep the exact same pet and the exact same outfit it is wearing."
                    if trigger else _build_worn_prompt(style, composition, None)
                )
            else:
                stage2_prompt = _build_prompt(
                    product, pet, style, composition, background,
                    trigger=trigger, lora_active=bool(lora),
                )

        def _run() -> tuple[str, str, str]:
            # 1단계: 실제 상품 옷 착용(있을 때). 결과 바이트를 2단계 입력으로.
            input_uri = _data_uri(pet_image)
            if two_stage:
                g_bytes, g_mime = garment
                worn_url = _predict(settings.multi_image_model, {
                    "input_image_1": _data_uri(pet_image),
                    "input_image_2": _data_uri(g_bytes, g_mime),
                    "prompt": _WEAR_PROMPT,
                    "aspect_ratio": "match_input_image",
                    "output_format": "png",
                })
                input_uri = _data_uri(_fetch_bytes(worn_url))

            # 2단계(또는 단일): LoRA > 학습모델 > 기본편집+프롬프트 폴백.
            if lora:
                m = settings.kontext_lora_model
                pay = {
                    "prompt": stage2_prompt,
                    "input_image": input_uri,
                    "lora_weights": lora,
                    "lora_strength": settings.lora_strength,
                    "aspect_ratio": "match_input_image",
                    "num_inference_steps": settings.lora_steps,
                    "output_format": "png",
                    "output_quality": settings.lora_output_quality,
                }
                if settings.lora_guidance > 0:  # 스키마 확실치 않은 노브 → 설정됐을 때만
                    pay["guidance"] = settings.lora_guidance
                if seed is not None:  # 인생네컷 4컷을 같은 배경/조명으로 묶기(포즈만 변화)
                    pay["seed"] = seed
                t = f"2stage+LoRA:{style}" if two_stage else f"LoRA:{style}"
            else:
                m = trained_model or settings.replicate_model
                pay = {"prompt": stage2_prompt, "input_image": input_uri}
                if seed is not None:
                    pay["seed"] = seed
                t = ("2stage+" if two_stage else "") + (f"model:{style}" if trained_model else "prompt")
            return _predict(m, pay), m, t

        url, model, tag = await anyio.to_thread.run_sync(_run)
        if not url:
            raise RuntimeError("Replicate 출력이 비어 있습니다.")
        analysis = f"{pet_name}의 체형에는 {rec} 사이즈가 잘 맞아요. (Replicate {model} · {tag})"
        return ProviderOutput(
            fit_score=product.fit,
            recommended_size=rec,
            analysis=analysis,
            image_url=url,
        )

    async def lora_fourcut_cut(
        self, *, lora_url: str, trigger: str, pose_key: str, seed: Optional[int] = None,
    ) -> Optional[bytes]:
        """펫 전용 LoRA txt2img 로 인생네컷 고정포즈 한 컷을 '생성'(사진 편집 아님).

        LoRA 가 정체성을 들고 있어 포즈를 자유롭게 고정 지시해도 같은 아이로 나온다.
        4컷을 같은 seed 로 부르면 배경·조명이 묶여 포토부스 스트립 통일감이 생긴다.
        실패 시 None(호출부에서 재시도/플레이스홀더 처리).
        """
        pose = LORA_FOURCUT_POSES.get(pose_key)
        if not (pose and settings.replicate_token):
            return None
        prompt = f"photo of {trigger}, {pose}, {FOURCUT_BOOTH}"

        def _run() -> bytes:
            pay = {
                "prompt": prompt,
                "lora_weights": lora_url,
                "lora_scale": settings.lora_strength,
                "aspect_ratio": "1:1",
                "num_inference_steps": 28,   # fal 실험과 동일값(검증 2026-07-11)
                "guidance": 3.5,
                "output_format": "png",
                # go_fast(fp8 양자화, 기본 True)는 LoRA 디테일을 뭉갠다(A/B 2026-07-11:
                # 털 질감·눈 캐치라이트 손실). 품질 크리티컬이라 bf16 고정.
                "go_fast": False,
            }
            if seed is not None:
                pay["seed"] = seed
            return _fetch_bytes(_predict(settings.flux_lora_model, pay))

        try:
            return await anyio.to_thread.run_sync(_run)
        except Exception:  # noqa: BLE001 — 셀 단위 복원력(호출부가 재시도)
            return None

    async def wear_garment(self, *, pet_image: bytes, product: Product) -> Optional[bytes]:
        """멀티이미지 kontext 로 펫에 '실제 상품 옷'을 입힌 이미지 바이트를 반환.

        인생네컷에서 옷 착용을 1번만 하고 그 결과로 여러 컷을 파생시키기 위한 사전 단계.
        상품 옷(ref_image)이 없거나·기능 off·실패하면 None(호출부에서 원본 펫으로 폴백).
        """
        if not (settings.replicate_token and settings.two_stage_fitting) or pet_image is None:
            return None
        g = _load_garment(product)
        if not g:
            return None
        g_bytes, g_mime = g

        def _run() -> Optional[bytes]:
            url = _predict(settings.multi_image_model, {
                "input_image_1": _data_uri(pet_image),
                "input_image_2": _data_uri(g_bytes, g_mime),
                "prompt": _WEAR_PROMPT,
                "aspect_ratio": "match_input_image",
                "output_format": "png",
            })
            return _fetch_bytes(url)

        try:
            return await anyio.to_thread.run_sync(_run)
        except Exception:  # noqa: BLE001 — 착용 실패 시 원본 펫으로 진행
            return None
