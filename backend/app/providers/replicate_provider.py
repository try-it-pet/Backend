import io
from typing import Optional

import anyio

from ..config import settings
from ..models import Pet, Product
from .base import ProviderOutput, TryOnProvider
from .mock import recommend_size


def _build_prompt(
    product: Product,
    pet: Optional[Pet],
    style: Optional[str] = None,
    composition: Optional[str] = None,
    background: Optional[str] = None,
) -> str:
    from .openai_provider import (  # 프리셋 단일 출처
        BACKGROUND_PRESETS,
        COMPOSITION_PRESETS,
        STYLE_PRESETS,
    )

    pet_desc = f"{pet.species}" if pet else "pet"
    base = (
        f"Dress this {pet_desc} in a {product.name} ({product.brand}), a piece of pet clothing. "
        f"Photorealistic, keep the pet's identity, fur, face and pose; the garment fits naturally."
    )
    extras: list[str] = []
    if style in STYLE_PRESETS:
        extras.append(f"Style: {STYLE_PRESETS[style]}.")
    if composition in COMPOSITION_PRESETS:
        extras.append(f"Composition: {COMPOSITION_PRESETS[composition]}.")
    extras.append(BACKGROUND_PRESETS.get(background or "studio", BACKGROUND_PRESETS["studio"]))
    return base + " " + " ".join(extras)


class ReplicateProvider(TryOnProvider):
    """Replicate 호스팅 이미지 편집 모델로 펫에 옷을 입힌다.

    기본 모델은 settings.replicate_model(이미지 편집형). 모델마다 input 키가
    다를 수 있으므로, 모델 교체 시 _call 의 input 매핑만 맞추면 된다.
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
        prompt = _build_prompt(product, pet, style, composition, background)

        def _call() -> str:
            client = replicate.Client(api_token=settings.replicate_token)
            output = client.run(
                settings.replicate_model,
                input={"prompt": prompt, "input_image": io.BytesIO(pet_image)},
            )
            if isinstance(output, list):
                output = output[0] if output else ""
            return str(output)

        url = await anyio.to_thread.run_sync(_call)
        if not url:
            raise RuntimeError("Replicate 출력이 비어 있습니다.")
        analysis = f"{pet_name}의 체형에는 {rec} 사이즈가 잘 맞아요. (Replicate {settings.replicate_model})"
        return ProviderOutput(
            fit_score=product.fit,
            recommended_size=rec,
            analysis=analysis,
            image_url=url,
        )
