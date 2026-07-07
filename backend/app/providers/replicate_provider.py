import io
from typing import Optional

import anyio

from ..config import settings
from ..models import Pet, Product
from .base import ProviderOutput, TryOnProvider
from .looks import (
    BACKGROUND_PRESETS,
    COMPOSITION_PRESETS,
    IDENTITY_LOCK,
    ILLUSTRATION_LOOKS,
    LOOK_PROMPTS,
    QUALITY_BOOST,
    SCENE_LOOKS,
    is_illustration,
    look_lora,
    look_model,
    look_trigger,
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
    base = (
        f"Dress this {pet_desc} in a {product.name} ({product.brand}), a piece of pet clothing. "
        f"Photorealistic, the garment fits naturally. {IDENTITY_LOCK}"
    )
    extras: list[str] = []
    if trigger:  # LoRA 트리거(예: apply Pawdy winter) — 학습된 감성이 발동됨
        extras.append(f"{trigger} style.")
    # 학습된 LoRA 가 활성일 때는 룩 아트디렉션 대문단을 생략한다. LoRA 가 이미 룩을 인코딩하므로
    # 긴 지시문은 LoRA 와 충돌해 정체성 드리프트를 키운다(README: 과지시 방지). 폴백(LoRA 없음)일
    # 때만 프롬프트로 룩을 연출한다.
    if not lora_active and style in LOOK_PROMPTS:
        extras.append(f"Style: {LOOK_PROMPTS[style]}.")
    if composition in COMPOSITION_PRESETS:
        extras.append(f"Composition: {COMPOSITION_PRESETS[composition]}.")
    if style not in SCENE_LOOKS:
        extras.append(BACKGROUND_PRESETS.get(background or "studio", BACKGROUND_PRESETS["studio"]))
    extras.append(QUALITY_BOOST)
    return base + " " + " ".join(extras)


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
        prompt = _build_prompt(
            product, pet, style, composition, background,
            trigger=trigger, lora_active=bool(lora),
        )

        if lora:
            model = settings.kontext_lora_model
            # 린 프롬프트(과지시 제거) + 정체성 보존 파라미터. lora_strength 를 낮추면 입력 펫의
            # 정체성이 더 보존되고, 높이면 학습된 룩이 강해진다(트레이드오프).
            payload = {
                "prompt": prompt,
                "input_image": io.BytesIO(pet_image),
                "lora_weights": lora,
                "lora_strength": settings.lora_strength,
                "aspect_ratio": "match_input_image",
                "num_inference_steps": settings.lora_steps,
                "output_format": "png",
                "output_quality": settings.lora_output_quality,
            }
            if settings.lora_guidance > 0:  # 스키마 확실치 않은 노브 → 설정됐을 때만 전송
                payload["guidance"] = settings.lora_guidance
            tag = f"LoRA:{style}"
        else:
            model = trained_model or settings.replicate_model
            payload = {"prompt": prompt, "input_image": io.BytesIO(pet_image)}
            tag = f"model:{style}" if trained_model else "prompt"

        def _call() -> str:
            # client.run() 은 LoRA 콜드스타트 시 내부 타임아웃에 걸림 →
            # 예측 API 직접 생성 + 자체 폴링(요청별 타임아웃만, 총 대기 길게)으로 안전하게.
            import base64
            import time

            import httpx as hx

            tok = settings.replicate_token
            headers = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}
            inp = {k: v for k, v in payload.items() if k != "input_image"}
            inp["input_image"] = "data:image/png;base64," + base64.b64encode(pet_image).decode()

            if ":" in model:  # owner/name:version
                version = model.split(":", 1)[1]
            else:  # 공식 모델 슬러그 → 최신 버전 조회
                version = replicate.Client(api_token=tok).models.get(model).latest_version.id

            r = hx.post("https://api.replicate.com/v1/predictions", headers=headers,
                        json={"version": version, "input": inp}, timeout=60)
            r.raise_for_status()
            pid = r.json()["id"]
            for _ in range(120):  # 최대 ~6분 (콜드스타트 포함)
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

        url = await anyio.to_thread.run_sync(_call)
        if not url:
            raise RuntimeError("Replicate 출력이 비어 있습니다.")
        analysis = f"{pet_name}의 체형에는 {rec} 사이즈가 잘 맞아요. (Replicate {model} · {tag})"
        return ProviderOutput(
            fit_score=product.fit,
            recommended_size=rec,
            analysis=analysis,
            image_url=url,
        )
