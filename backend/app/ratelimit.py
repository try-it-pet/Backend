"""IP 기반 인메모리 슬라이딩 윈도우 레이트리밋 — 인증(무차별 대입)·민감 엔드포인트 방어.

quota.py 의 생성용 IP 제한과 별개 버킷. 단일 인스턴스(Railway) 전제의 인메모리 구현이며,
다중 워커/인스턴스로 확장 시 Redis 등으로 교체한다.
"""

import time
from typing import Dict, List, Optional

from fastapi import HTTPException, Request

from .config import settings

_HITS: Dict[str, List[float]] = {}


def client_ip(request: Optional[Request]) -> Optional[str]:
    if request is None:
        return None
    fwd = request.headers.get("x-forwarded-for")  # Railway/프록시 뒤 실제 IP
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else None


def allow(bucket: str, key: Optional[str], per_min: int) -> bool:
    """bucket(용도)별·key(IP 등)별 분당 per_min 회 허용. key 없으면 통과(프록시 뒤 안전빵)."""
    if per_min <= 0 or not key:
        return True
    k = f"{bucket}:{key}"
    now = time.time()
    hits = [t for t in _HITS.get(k, []) if t > now - 60]
    if len(hits) >= per_min:
        _HITS[k] = hits
        return False
    hits.append(now)
    _HITS[k] = hits
    return True


def guard_auth(request: Request) -> None:
    """인증 엔드포인트 공용 가드 — 초과 시 429."""
    if not allow("auth", client_ip(request), settings.auth_rate_per_min):
        raise HTTPException(status_code=429, detail="시도가 너무 많아요. 잠시 후 다시 시도해주세요.")
