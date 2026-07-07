"""출력 업스케일 후처리 — 생성 결과의 해상도·디테일을 Real-ESRGAN(Replicate)으로 끌어올린다.

편집 모델 출력이 1024px 급이라 확대 시 뭉개지는 문제를 완화한다. env 게이트(PETFIT_UPSCALE)로
켜고, Replicate 토큰이 있을 때만 동작한다. 실패하면 원본 바이트를 그대로 돌려준다(무해 폴백).

비용/시간이 늘어나므로 단일 tryon 결과에만 적용하고, 인생네컷(4컷×원가)에는 적용하지 않는다.
"""

from __future__ import annotations

import base64
import time
from typing import Optional

import anyio
import httpx

from .config import settings

_API = "https://api.replicate.com/v1/predictions"


def _run_upscale(data: bytes) -> Optional[bytes]:
    """Replicate Real-ESRGAN 예측 생성 → 폴링 → 업스케일된 이미지 바이트. 실패 시 None."""
    tok = settings.replicate_token
    headers = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}

    model = settings.upscale_model
    if ":" in model:  # owner/name:version
        version = model.split(":", 1)[1]
    else:  # 슬러그 → 최신 버전 조회
        import replicate

        version = replicate.Client(api_token=tok).models.get(model).latest_version.id

    inp = {
        "image": "data:image/png;base64," + base64.b64encode(data).decode(),
        "scale": settings.upscale_factor,
    }
    r = httpx.post(_API, headers=headers, json={"version": version, "input": inp}, timeout=60)
    r.raise_for_status()
    pid = r.json()["id"]
    for _ in range(60):  # 최대 ~3분
        time.sleep(3)
        s = httpx.get(f"{_API}/{pid}", headers=headers, timeout=30).json()
        st = s.get("status")
        if st == "succeeded":
            out = s.get("output")
            url = str(out[0] if isinstance(out, list) else out)
            got = httpx.get(url, timeout=60, follow_redirects=True)
            return got.content if got.status_code == 200 else None
        if st in ("failed", "canceled"):
            return None
    return None


async def maybe_upscale(data: Optional[bytes]) -> Optional[bytes]:
    """설정이 켜져 있고 가능하면 업스케일, 아니면 입력 그대로 반환(예외 없이)."""
    if not data or not settings.upscale_enabled or not settings.replicate_token:
        return data
    try:
        out = await anyio.to_thread.run_sync(_run_upscale, data)
        return out or data
    except Exception:  # noqa: BLE001 — 업스케일 실패는 원본으로 폴백
        return data
