"""입력 펫 사진 전처리 — bad input = bad output 을 막는 첫 방어선.

프로바이더(gpt-image-2 / flux-kontext)에 넘기기 전에 사진을 정규화한다:
  - EXIF 방향 보정(스마트폰 세로 사진이 눕는 문제 제거)
  - RGB 변환(알파/CMYK/팔레트 → 편집 모델이 다루기 쉬운 포맷)
  - 과대 이미지 다운스케일(장변 상한) — 편집 모델 내부 리사이즈 손실·요금 방어
  - 너무 작은 사진은 적당히 확대(디테일 부족 완화)
  - PNG 재인코딩(SDK가 확장자로 MIME 을 정하므로 안전)

의도적으로 크롭은 하지 않는다 — 펫이 프레임 가장자리에 있을 때 잘려 나가면
오히려 정체성/구도가 망가진다. 크롭은 fourcut 합성 등 후단에서만.
"""

from __future__ import annotations

import io

from PIL import Image, ImageOps

# 편집 모델에 넘길 장변 상한/하한(px). 상한 초과는 축소, 하한 미만은 확대.
MAX_DIM = 1536
MIN_DIM = 768


def prepare_pet_image(data: bytes) -> bytes:
    """원본 펫 사진 바이트 → 정규화된 PNG 바이트. 실패 시 원본을 그대로 반환한다.

    호출부에서 CPU 블로킹을 피하려면 `asyncio.to_thread(prepare_pet_image, data)` 로.
    """
    if not data:
        return data
    try:
        im = Image.open(io.BytesIO(data))
        im = ImageOps.exif_transpose(im)  # 촬영 방향 반영(회전 메타 → 실제 픽셀)
        if im.mode != "RGB":
            im = im.convert("RGB")

        w, h = im.size
        long_side = max(w, h)
        short_side = min(w, h)

        # 과대 → 축소(장변 MAX_DIM). 과소 → 확대(단변 MIN_DIM)하되 과확대는 피함.
        if long_side > MAX_DIM:
            scale = MAX_DIM / long_side
        elif short_side < MIN_DIM:
            scale = min(MIN_DIM / short_side, 2.0)  # 최대 2배까지만 업샘플
        else:
            scale = 1.0

        if scale != 1.0:
            im = im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)

        buf = io.BytesIO()
        im.save(buf, format="PNG")
        return buf.getvalue()
    except Exception:  # noqa: BLE001 — 전처리는 best-effort, 실패해도 원본으로 진행
        return data
