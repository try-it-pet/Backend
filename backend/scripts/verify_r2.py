"""R2 설정 검증 — 업로드 → 공개 URL GET 200 확인.

사용:  (backend/.env 에 PETFIT_R2_* 5개 넣은 뒤)
    cd backend && .venv/Scripts/python.exe scripts/verify_r2.py

Railway 에서 확인하려면 배포 후:  curl <백엔드>/health  → "storage":"r2" 면 설정 완료.
"""

import sys
import time

import httpx

sys.path.insert(0, ".")

from app.config import settings  # noqa: E402
from app.storage import put_bytes  # noqa: E402

REQUIRED = {
    "PETFIT_R2_ENDPOINT": settings.r2_endpoint,
    "PETFIT_R2_ACCESS_KEY_ID": settings.r2_access_key,
    "PETFIT_R2_SECRET_ACCESS_KEY": settings.r2_secret_key,
    "PETFIT_R2_BUCKET": settings.r2_bucket,
    "PETFIT_R2_PUBLIC_BASE": settings.r2_public_base,
}


def main() -> int:
    missing = [k for k, v in REQUIRED.items() if not v]
    if missing:
        print("❌ 누락된 env:", ", ".join(missing))
        print("   → 이 5개를 backend/.env(로컬) 또는 Railway Variables 에 설정하세요.")
        return 1

    print("설정 확인:")
    print(f"  endpoint    = {settings.r2_endpoint}")
    print(f"  bucket      = {settings.r2_bucket}")
    print(f"  public_base = {settings.r2_public_base}")

    key = f"healthcheck/verify-{int(time.time())}.txt"
    body = b"pawdy r2 ok"
    print(f"\n업로드 시도: {key}")
    url = put_bytes(key, body, "text/plain")
    if not url:
        print("❌ 업로드 실패 — Access Key/Secret/Endpoint/Bucket 확인 필요.")
        return 1
    print(f"✅ 업로드 성공 → {url}")

    print("\n공개 URL 접근 확인(GET)…")
    try:
        r = httpx.get(url, timeout=15)
    except Exception as e:  # noqa: BLE001
        print(f"❌ GET 실패: {e}")
        return 1
    if r.status_code == 200 and r.content == body:
        print("✅ 공개 접근 OK — R2 설정 완료! 이제 생성 이미지가 영구 저장됩니다.")
        return 0
    print(f"❌ 공개 접근 실패 (status={r.status_code}). "
          "R2 버킷의 Public access(R2.dev) 활성화 + PUBLIC_BASE 정확한지 확인.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
