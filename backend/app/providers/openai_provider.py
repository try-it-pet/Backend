import base64
import io
from typing import Optional

import anyio

from ..config import settings
from ..models import Pet, Product
from .base import ProviderOutput, TryOnProvider
from .mock import recommend_size


def _build_prompt(product: Product, pet: Optional[Pet]) -> str:
    pet_desc = f"{pet.species}" if pet else "pet"
    return (
        f"Dress this {pet_desc} in a '{product.name}' by {product.brand}, a piece of pet clothing. "
        f"Photorealistic result. Keep the pet's identity, fur pattern, face, and pose unchanged — "
        f"only add the garment so it fits naturally on the body. Soft, clean studio background."
    )


class OpenAIProvider(TryOnProvider):
    """OpenAI gpt-image-2 이미지 편집(edit)으로 펫에 옷을 입힌다.

    펫 사진을 입력 이미지로, 상품 정보를 프롬프트로 사용. 상품 레퍼런스 이미지가
    생기면 다중 이미지 입력으로 품질을 더 올릴 수 있다.
    """

    name = "openai"

    async def generate(
        self,
        *,
        product: Product,
        size: str,
        pet: Optional[Pet] = None,
        pet_image: Optional[bytes] = None,
    ) -> ProviderOutput:
        if not settings.openai_api_key:
            raise RuntimeError("PETFIT_OPENAI_API_KEY 가 설정되지 않았습니다.")
        if pet_image is None:
            raise RuntimeError("OpenAI 프로바이더는 펫 이미지(pet_image)가 필요합니다.")
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError("openai 패키지가 없습니다: pip install openai") from exc

        rec = size or recommend_size(pet)
        pet_name = pet.name if pet else "반려동물"
        prompt = _build_prompt(product, pet)

        def _call() -> bytes:
            client = OpenAI(api_key=settings.openai_api_key)
            img = io.BytesIO(pet_image)
            img.name = "pet.png"
            resp = client.images.edit(
                model=settings.openai_model,
                image=img,
                prompt=prompt,
                size=settings.openai_size,
            )
            return base64.b64decode(resp.data[0].b64_json)

        png = await anyio.to_thread.run_sync(_call)
        analysis = f"{pet_name}의 체형에는 {rec} 사이즈가 잘 맞아요. (OpenAI {settings.openai_model})"
        return ProviderOutput(
            fit_score=product.fit,
            recommended_size=rec,
            analysis=analysis,
            image_bytes=png,
            image_mime="image/png",
        )
