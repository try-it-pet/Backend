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


# 룩/구도/배경 프리셋은 looks.py 가 단일 출처(프롬프트 단계 ↔ LoRA 단계 공유).
from .looks import (  # noqa: E402
    BACKGROUND_PRESETS,
    COMPOSITION_PRESETS,
    IDENTITY_LOCK,
    ILLUSTRATION_LOOKS,
    LOOK_PROMPTS as STYLE_PRESETS,
    QUALITY_BOOST,
    SCENE_LOOKS,
    is_illustration,
)


def _build_prompt(
    product: Product,
    pet: Optional[Pet],
    has_ref: bool,
    style: Optional[str] = None,
    composition: Optional[str] = None,
    background: Optional[str] = None,
) -> str:
    # 일러스트 룩은 펫을 통째로 다시 그림 — 착장 base 대신 그림체 프롬프트만 사용.
    if is_illustration(style):
        p = ILLUSTRATION_LOOKS[style]
        if composition in COMPOSITION_PRESETS:
            p += f" Pose: {COMPOSITION_PRESETS[composition]}."
        return p + " " + QUALITY_BOOST
    pet_desc = f"{pet.species}" if pet else "pet"
    if has_ref:
        base = (
            f"Dress the {pet_desc} in the FIRST image with the exact clothing item shown in the "
            f"SECOND image (the product '{product.name}'). Photorealistic result. Fit the garment "
            f"naturally on its body. {IDENTITY_LOCK}"
        )
    else:
        base = (
            f"Dress this {pet_desc} in a '{product.name}' by {product.brand}, a piece of pet clothing. "
            f"Photorealistic. Fit the garment naturally on the body. {IDENTITY_LOCK}"
        )
    extras: list[str] = []
    if style in STYLE_PRESETS:
        extras.append(f"Style: {STYLE_PRESETS[style]}.")
    if composition in COMPOSITION_PRESETS:
        extras.append(f"Composition: {COMPOSITION_PRESETS[composition]}.")
    # 감성 룩(winter 등)은 배경까지 룩이 정하므로 studio/keep 배경 지시를 생략
    if style not in SCENE_LOOKS:
        extras.append(BACKGROUND_PRESETS.get(background or "studio", BACKGROUND_PRESETS["studio"]))
    extras.append(QUALITY_BOOST)
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
        seed: Optional[int] = None,  # openai images.edit 은 seed 미지원 → 무시
        worn: bool = False,  # openai 는 자체 멀티이미지 edit 사용 → 무시
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
            if product.ref_image and not is_illustration(style):  # 일러스트는 옷 레퍼런스 미사용
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
                        # SDK가 파일명 확장자로 MIME을 정하므로 실제 포맷과 일치시킴
                        ext = Path(ref.split("?")[0]).suffix.lower().lstrip(".") or "png"
                        g.name = f"garment.{'jpg' if ext == 'jpeg' else ext}"
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
