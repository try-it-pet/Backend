import os
from pathlib import Path
from typing import Optional

from .config import settings

_client = None


def configured() -> bool:
    return settings.r2_configured()


def _s3():
    global _client
    if _client is None:
        import boto3
        from botocore.config import Config

        _client = boto3.client(
            "s3",
            endpoint_url=settings.r2_endpoint,
            aws_access_key_id=settings.r2_access_key,
            aws_secret_access_key=settings.r2_secret_key,
            config=Config(signature_version="s3v4"),
            region_name="auto",
        )
    return _client


def put_bytes(key: str, data: bytes, mime: str = "application/octet-stream") -> Optional[str]:
    """R2 에 업로드하고 공개 URL 반환. 실패 시 로컬 static 업로드 폴백."""
    if configured():
        try:
            _s3().put_object(Bucket=settings.r2_bucket, Key=key, Body=data, ContentType=mime)
            return f"{settings.r2_public_base.rstrip('/')}/{key}"
        except Exception:  # noqa: BLE001
            pass

    # 로컬 폴백: app/static/uploads 디렉토리에 저장
    try:
        base_dir = Path(__file__).resolve().parent / "static" / "uploads"
        base_dir.mkdir(parents=True, exist_ok=True)
        # 경로 구분자(/)를 언더스코어(_)로 변환하여 로컬 파일명 충돌 방지
        filename = key.replace("/", "_")
        file_path = base_dir / filename
        file_path.write_bytes(data)
        return f"/static/uploads/{filename}"
    except Exception:
        return None

