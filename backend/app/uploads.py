"""업로드 이미지 검증 — 용량·형식·'실제 이미지인지'를 저장/생성 전에 확인한다.

확장자·Content-Type 은 클라이언트가 마음대로 보낼 수 있으므로 믿지 않고,
PIL 로 실제 디코딩되는 포맷을 기준으로 확장자/MIME 을 결정한다.
"""

import io
from typing import Tuple

from fastapi import HTTPException, UploadFile

# 허용 포맷: PIL format → (확장자, MIME)
_ALLOWED = {
    "JPEG": ("jpg", "image/jpeg"),
    "PNG": ("png", "image/png"),
    "WEBP": ("webp", "image/webp"),
}
MAX_IMAGE_MB = 10


def read_image_upload(file: UploadFile, max_mb: int = MAX_IMAGE_MB) -> Tuple[bytes, str, str]:
    """(bytes, ext, mime) 반환. 초과 용량 413, 비이미지/미지원 포맷 400."""
    limit = max_mb * 1024 * 1024
    data = file.file.read(limit + 1)
    if len(data) > limit:
        raise HTTPException(status_code=413, detail=f"이미지가 너무 커요 (최대 {max_mb}MB).")
    if not data:
        raise HTTPException(status_code=400, detail="빈 파일이에요.")
    try:
        from PIL import Image
        with Image.open(io.BytesIO(data)) as im:
            fmt = im.format
            im.verify()  # 손상/위장 파일 검출
    except HTTPException:
        raise
    except Exception:  # noqa: BLE001 — 디코딩 실패 = 이미지 아님
        raise HTTPException(status_code=400, detail="이미지 파일이 아니에요 (jpg/png/webp 지원).")
    if fmt not in _ALLOWED:
        raise HTTPException(status_code=400, detail="지원하지 않는 이미지 형식이에요 (jpg/png/webp).")
    ext, mime = _ALLOWED[fmt]
    return data, ext, mime
