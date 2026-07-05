#!/usr/bin/env python
"""fal LoRA(.safetensors) → Cloudflare R2 재호스팅(배포 안정성).

fal.media URL 은 3자 CDN 이라 만료/정리 리스크가 있음. R2 로 옮겨 우리가 관리한다.
업로드 후 나온 R2 공개 URL 을 PETFIT_LOOK_LORAS 에 등록하면 됨.

사전: backend/.env 에 PETFIT_R2_* 설정. pip install boto3 httpx.

사용:
  cd backend
  python scripts/rehost_lora.py --look winter --url "https://v3b.fal.media/.../adapter_model.safetensors"
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.config import settings  # noqa: E402
from app.storage import configured, put_bytes  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser(description="fal LoRA → R2 재호스팅")
    ap.add_argument("--look", required=True, help="룩 키 (예: winter)")
    ap.add_argument("--url", required=True, help="원본 LoRA URL(fal.media 등)")
    args = ap.parse_args()

    if not configured():
        sys.exit("R2 미설정(PETFIT_R2_*). backend/.env 확인.")
    import httpx

    print(f"[rehost] 다운로드: {args.url[:70]}...")
    data = httpx.get(args.url, timeout=120, follow_redirects=True).content
    print(f"[rehost] {len(data)/1e6:.1f}MB → R2 업로드")
    key = f"loras/pawdy-{args.look}.safetensors"
    url = put_bytes(key, data, "application/octet-stream")
    if not url:
        sys.exit("[rehost] R2 업로드 실패")
    print("\n[rehost] 완료! R2 URL:")
    print(f"  {url}")
    print("\n  백엔드 등록(Railway Variables):")
    print(f'    PETFIT_LOOK_LORAS=\'{{"{args.look}": "{url}"}}\'')


if __name__ == "__main__":
    main()
