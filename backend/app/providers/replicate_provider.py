import io
from typing import Optional

import anyio

from ..config import settings
from ..models import Pet, Product
from .base import ProviderOutput, TryOnProvider
from .looks import (
    BACKGROUND_PRESETS,
    COMPOSITION_PRESETS,
    LOOK_PROMPTS,
    SCENE_LOOKS,
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
    trained: bool = False,
) -> str:
    pet_desc = f"{pet.species}" if pet else "pet"
    base = (
        f"Dress this {pet_desc} in a {product.name} ({product.brand}), a piece of pet clothing. "
        f"Photorealistic, keep the pet's identity, fur, face and pose; the garment fits naturally."
    )
    extras: list[str] = []
    # 학습된 LoRA 를 쓸 땐 룩 프롬프트를 트리거로 대체(과지시 방지) — 아트디렉션은 가중치에 각인됨.
    trigger = look_trigger(style)
    if trained and trigger:
        extras.append(f"{trigger} style.")
    elif style in LOOK_PROMPTS:
        extras.append(f"Style: {LOOK_PROMPTS[style]}.")
    if composition in COMPOSITION_PRESETS:
        extras.append(f"Composition: {COMPOSITION_PRESETS[composition]}.")
    if style not in SCENE_LOOKS:
        extras.append(BACKGROUND_PRESETS.get(background or "studio", BACKGROUND_PRESETS["studio"]))
    return base + " " + " ".join(extras)


class ReplicateProvider(TryOnProvider):
    """Replicate 호스팅 이미지 편집 모델(Flux Kontext)로 펫에 옷을 입힌다.

    감성 룩(style)에 학습된 LoRA 모델이 등록돼 있으면(PETFIT_LOOK_MODELS) 그 모델로,
    없으면 기본 편집 모델(settings.replicate_model) + 룩 프롬프트로 폴백한다.
    모델마다 input 키가 다를 수 있으므로, 모델 교체 시 _call 의 input 매핑만 맞추면 된다.
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

        # 이 룩에 학습된 LoRA 모델이 있으면 그걸 사용(진짜 Pawdy 감성), 없으면 프롬프트 폴백.
        trained_model = look_model(style)
        model = trained_model or settings.replicate_model
        prompt = _build_prompt(
            product, pet, style, composition, background, trained=bool(trained_model)
        )

        def _call() -> str:
            client = replicate.Client(api_token=settings.replicate_token)
            output = client.run(
                model,
                input={"prompt": prompt, "input_image": io.BytesIO(pet_image)},
            )
            if isinstance(output, list):
                output = output[0] if output else ""
            return str(output)

        url = await anyio.to_thread.run_sync(_call)
        if not url:
            raise RuntimeError("Replicate 출력이 비어 있습니다.")
        tag = f"LoRA:{style}" if trained_model else "prompt"
        analysis = f"{pet_name}의 체형에는 {rec} 사이즈가 잘 맞아요. (Replicate {model} · {tag})"
        return ProviderOutput(
            fit_score=product.fit,
            recommended_size=rec,
            analysis=analysis,
            image_url=url,
        )
