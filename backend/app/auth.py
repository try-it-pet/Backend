from datetime import datetime, timedelta, timezone
from typing import Optional

import jwt
from fastapi import Header, HTTPException

from .config import settings
from .models import User
from .store import USERS


def create_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(days=settings.jwt_expire_days),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def _user_from_token(token: str) -> Optional[User]:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        return USERS.get(int(payload["sub"]))
    except Exception:  # noqa: BLE001 (만료/위조/형식오류 모두 무효 토큰)
        return None


def _extract(authorization: Optional[str]) -> Optional[str]:
    if not authorization:
        return None
    parts = authorization.split()
    if len(parts) == 2 and parts[0].lower() == "bearer":
        return parts[1]
    return None


def get_current_user(authorization: Optional[str] = Header(None)) -> User:
    """Bearer JWT 필수. 무효/없음 → 401."""
    user = _user_from_token(_extract(authorization) or "")
    if user is None:
        raise HTTPException(status_code=401, detail="인증이 필요합니다")
    return user


def get_optional_user(authorization: Optional[str] = Header(None)) -> Optional[User]:
    """있으면 사용자, 없으면 None (비로그인 허용 엔드포인트용)."""
    return _user_from_token(_extract(authorization) or "")
