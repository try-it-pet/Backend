import base64
import io
from pathlib import Path
from typing import Optional

import anyio
import httpx

from ..config import settings
from ..models import Pet, Product
from .base import ProviderOutput, TryOnProvider
from .mock import recommend_size


# 구도/사진풍 프리셋 — 프론트 칩과 1:1 대응. 키가 없으면 무시(자유 생성).
STYLE_PRESETS = {
    "studio": "clean catalog studio photo, even soft lighting, crisp focus",
    "lifestyle": "lifestyle photo at home or on a walk, natural ambient light, shallow depth of field",
    "film": "warm analog film look, soft grain, gentle highlights",
    "snap": "candid smartphone snapshot, natural daylight, relaxed everyday mood",
}
COMPOSITION_PRESETS = {
    "front_full": "front-facing full-body framing with the whole pet visible",
    "side": "side profile, full body in frame",
    "closeup": "close-up on the upper body and face, the garment clearly visible",
    "sitting": "the pet sitting in a three-quarter view, full body in frame",
}
BACKGROUND_PRESETS = {
    "studio": "Replace the background with a soft, clean studio backdrop.",
    "keep": "Preserve the original background and setting of the first image.",
}


def _build_prompt(
    product: Product,
    pet: Optional[Pet],
    has_ref: bool,
    style: Optional[str] = None,
    composition: Optional[str] = None,
    background: Optional[str] = None,
) -> str:
    pet_desc = f"{pet.species}" if pet else "pet"
    if has_ref:
        base = (
            f"Dress the {pet_desc} in the FIRST image with the exact clothing item shown in the "
            f"SECOND image (the product '{product.name}'). Photorealistic result. Keep the pet's "
            f"identity, fur pattern, face and pose unchanged; fit the garment naturally on its body."
        )
    else:
        base = (
            f"Dress this {pet_desc} in a '{product.name}' by {product.brand}, a piece of pet clothing. "
            f"Photorealistic. Keep the pet's identity, fur, face, and pose unchanged — only add the "
            f"garment so it fits naturally on the body."
        )
    extras: list[str] = []
    if style in STYLE_PRESETS:
        extras.append(f"Style: {STYLE_PRESETS[style]}.")
    if composition in COMPOSITION_PRESETS:
        extras.append(f"Composition: {COMPOSITION_PRESETS[composition]}.")
    extras.append(BACKGROUND_PRESETS.get(background or "studio", BACKGROUND_PRESETS["studio"]))
    return base + " " + " ".join(extras)


class OpenAIProvider(TryOnProvider):
    """OpenAI gpt-image-2 이미지 편집(edit)으로 펫에 옷을 입힌다.

    상품에 ref_image(옷 레퍼런스)가 있으면 [펫 사진, 옷 사진] 두 장을 넣어
    그 옷을 그대로 입힌다. 없으면 상품명 프롬프트만 사용.
    """

    name = "openai"

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

        def _call() -> bytes:
            client = OpenAI(api_key=settings.openai_api_key)
            pet_io = io.BytesIO(pet_image)
            pet_io.name = "pet.png"
            images: list = [pet_io]
            if product.ref_image:
                try:
                    ref = product.ref_image
                    if ref.startswith("/static/"):
                        # 백엔드 내부 정적 상품컷 → 로컬 파일에서 직접 읽기
                        fp = Path(__file__).resolve().parent.parent / ref.lstrip("/")
                        data = fp.read_bytes()
                    else:
                        data = httpx.get(ref, timeout=20, follow_redirects=True).content
                    if data:
                        g = io.BytesIO(data)
                        g.name = "garment.png"
                        images.append(g)
                except Exception:  # noqa: BLE001 (레퍼런스 실패 시 프롬프트만으로 진행)
                    pass
            prompt = _build_prompt(
                product, pet, has_ref=len(images) > 1,
                style=style, composition=composition, background=background,
            )
            resp = client.images.edit(
                model=settings.openai_model,
                image=images if len(images) > 1 else images[0],
                prompt=prompt,
                size=settings.openai_size,
            )
            return base64.b64decode(resp.data[0].b64_json)

        png = await anyio.to_thread.run_sync(_call)
        used_ref = " (옷 레퍼런스 반영)" if product.ref_image else ""
        analysis = f"{pet_name}의 체형에는 {rec} 사이즈가 잘 맞아요. (OpenAI {settings.openai_model}{used_ref})"
        return ProviderOutput(
            fit_score=product.fit,
            recommended_size=rec,
            analysis=analysis,
            image_bytes=png,
            image_mime="image/png",
        )
