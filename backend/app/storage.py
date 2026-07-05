"""오브젝트 스토리지(Cloudflare R2, S3 호환) — 생성 결과 이미지·LoRA 저장.

R2 크레덴셜이 설정되면 R2 에 업로드하고 공개 URL 을 돌려준다. 미설정이면 configured()=False
→ 호출측이 DB 폴백. R2 는 이그레스 무료라 이미지 트래픽 많은 우리에 유리.
"""

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
    """R2 에 업로드하고 공개 URL 반환. 실패 시 None."""
    if not configured():
        return None
    try:
        _s3().put_object(Bucket=settings.r2_bucket, Key=key, Body=data, ContentType=mime)
        return f"{settings.r2_public_base.rstrip('/')}/{key}"
    except Exception:  # noqa: BLE001 (업로드 실패 → 호출측 DB 폴백)
        return None
