from typing import Optional
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Body, Depends, HTTPException
from fastapi.responses import RedirectResponse

from ..auth import create_token, get_current_user
from ..config import settings
from ..models import AuthResult, User
from ..store import create_dev_user, upsert_kakao_user

router = APIRouter(prefix="/auth", tags=["auth"])

KAKAO_AUTH = "https://kauth.kakao.com/oauth/authorize"
KAKAO_TOKEN = "https://kauth.kakao.com/oauth/token"
KAKAO_ME = "https://kapi.kakao.com/v2/user/me"


@router.get("/kakao/login")
def kakao_login() -> RedirectResponse:
    """카카오 인가 페이지로 리다이렉트. (PETFIT_KAKAO_REST_API_KEY 필요)"""
    if not settings.kakao_rest_api_key:
        raise HTTPException(status_code=400, detail="카카오 키(PETFIT_KAKAO_REST_API_KEY) 미설정")
    q = urlencode({
        "response_type": "code",
        "client_id": settings.kakao_rest_api_key,
        "redirect_uri": settings.kakao_redirect_uri,
    })
    return RedirectResponse(f"{KAKAO_AUTH}?{q}")


@router.get("/kakao/callback")
async def kakao_callback(code: str) -> RedirectResponse:
    """카카오 콜백: code→토큰→프로필→유저 생성→우리 JWT 발급→프론트로 리다이렉트."""
    if not settings.kakao_rest_api_key:
        raise HTTPException(status_code=400, detail="카카오 키 미설정")
    async with httpx.AsyncClient(timeout=10) as client:
        tok = await client.post(KAKAO_TOKEN, data={
            "grant_type": "authorization_code",
            "client_id": settings.kakao_rest_api_key,
            "redirect_uri": settings.kakao_redirect_uri,
            "code": code,
        })
        tok.raise_for_status()
        access = tok.json()["access_token"]
        me = await client.get(KAKAO_ME, headers={"Authorization": f"Bearer {access}"})
        me.raise_for_status()
        data = me.json()
    profile = (data.get("kakao_account") or {}).get("profile") or {}
    user = upsert_kakao_user(
        kakao_id=str(data["id"]),
        nickname=profile.get("nickname") or "카카오 사용자",
        image=profile.get("profile_image_url"),
    )
    token = create_token(user.id)
    # SPA 로 토큰 전달
    return RedirectResponse(f"{settings.frontend_url}/?token={token}")


@router.post("/dev-login", response_model=AuthResult)
def dev_login(nickname: str = Body("초코집사", embed=True)) -> AuthResult:
    """키 없이 테스트용 로그인. 운영에선 PETFIT_ALLOW_DEV_LOGIN=0 으로 비활성화."""
    if not settings.allow_dev_login:
        raise HTTPException(status_code=403, detail="dev-login 비활성화됨")
    user = create_dev_user(nickname)
    return AuthResult(token=create_token(user.id), user=user)


@router.get("/me", response_model=User, tags=["auth"])
def me(user: User = Depends(get_current_user)) -> User:
    return user
