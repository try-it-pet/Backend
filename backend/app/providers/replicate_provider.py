import io
from typing import Optional

import anyio

from ..config import settings
from ..models import Pet, Product
from .base import ProviderOutput, TryOnProvider
from .looks import (
    BACKGROUND_PRESETS,
    COMPOSITION_PRESETS,
    ILLUSTRATION_LOOKS,
    LOOK_PROMPTS,
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
) -> str:
    if is_illustration(style):  # 일러스트 룩: 옷 없이 펫을 다시 그림
        p = ILLUSTRATION_LOOKS[style]
        if composition in COMPOSITION_PRESETS:
            p += f" Pose: {COMPOSITION_PRESETS[composition]}."
        return p
    pet_desc = f"{pet.species}" if pet else "pet"
    base = (
        f"Dress this {pet_desc} in a {product.name} ({product.brand}), a piece of pet clothing. "
        f"Photorealistic, keep the pet's identity, fur, face and pose; the garment fits naturally."
    )
    extras: list[str] = []
    if trigger:  # LoRA 트리거(예: PAWDYWINTER) — 학습된 감성이 발동됨
        extras.append(f"{trigger} style.")
    if style in LOOK_PROMPTS:  # 룩 아트디렉션(장면/색감) — Kontext 편집 지시
        extras.append(f"Style: {LOOK_PROMPTS[style]}.")
    if composition in COMPOSITION_PRESETS:
        extras.append(f"Composition: {COMPOSITION_PRESETS[composition]}.")
    if style not in SCENE_LOOKS:
        extras.append(BACKGROUND_PRESETS.get(background or "studio", BACKGROUND_PRESETS["studio"]))
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
        prompt = _build_prompt(product, pet, style, composition, background, trigger=trigger)

        if lora:
            model = settings.kontext_lora_model
            # 정체성 보존 강화(드리프트 방지) + 프로덕션 품질 파라미터.
            fidelity = (
                " Preserve the exact same pet: identity, fur colors, markings and pose; "
                "do not change the breed."
            )
            payload = {
                "prompt": prompt + fidelity,
                "input_image": io.BytesIO(pet_image),
                "lora_weights": lora,
                "lora_strength": settings.lora_strength,
                "aspect_ratio": "match_input_image",
                "num_inference_steps": settings.lora_steps,
                "output_format": "png",
                "output_quality": settings.lora_output_quality,
            }
            tag = f"LoRA:{style}"
        else:
            model = trained_model or settings.replicate_model
            payload = {"prompt": prompt, "input_image": io.BytesIO(pet_image)}
            tag = f"model:{style}" if trained_model else "prompt"

        def _call() -> str:
            client = replicate.Client(api_token=settings.replicate_token)
            output = client.run(model, input=payload)
            if isinstance(output, list):
                output = output[0] if output else ""
            return str(output)

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
