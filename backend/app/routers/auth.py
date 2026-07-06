import os
from typing import Optional
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Body, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from ..auth import create_token, get_current_user
from ..config import settings
from ..models import AuthResult, User
from ..store import create_dev_user, upsert_kakao_user

router = APIRouter(prefix="/auth", tags=["auth"])

KAKAO_AUTH = "https://kauth.kakao.com/oauth/authorize"
KAKAO_TOKEN = "https://kauth.kakao.com/oauth/token"
KAKAO_ME = "https://kapi.kakao.com/v2/user/me"


def _kakao_redirect_uri(request: Request) -> str:
    """카카오 콜백 URI. env 명시가 우선, 없으면 현재 요청 호스트로 자동 유도.

    (배포마다 env 를 맞출 필요 없도록. localhost 만 http, 그 외는 https 강제 —
    Railway 등 프록시 뒤에서는 request.url.scheme 이 http 로 보일 수 있음.)
    """
    if os.getenv("PETFIT_KAKAO_REDIRECT_URI"):
        return settings.kakao_redirect_uri
    host = request.url.netloc
    scheme = "http" if host.split(":")[0] in ("localhost", "127.0.0.1") else "https"
    return f"{scheme}://{host}/auth/kakao/callback"


@router.get("/kakao/login")
def kakao_login(request: Request) -> RedirectResponse:
    """카카오 인가 페이지로 리다이렉트. (PETFIT_KAKAO_REST_API_KEY 필요)

    ?next=<프론트 origin> 를 주면 로그인 후 그 주소로 복귀(state 로 전달).
    """
    if not settings.kakao_rest_api_key:
        raise HTTPException(status_code=400, detail="카카오 키(PETFIT_KAKAO_REST_API_KEY) 미설정")
    params = {
        "response_type": "code",
        "client_id": settings.kakao_rest_api_key,
        "redirect_uri": _kakao_redirect_uri(request),
    }
    next_ = request.query_params.get("next")
    if next_ and _allowed_frontend(next_):
        params["state"] = next_
    return RedirectResponse(f"{KAKAO_AUTH}?{urlencode(params)}")


def _allowed_frontend(origin: str) -> bool:
    """로그인 복귀(next) 허용 목록 — 오픈 리다이렉트 방지."""
    import re

    o = origin.rstrip("/")
    # 네이티브 앱(Flutter) 딥링크 복귀 — 카카오 콜백 후 앱으로 토큰 전달
    if o == "pawdy://login":
        return True
    if o == settings.frontend_url.rstrip("/"):
        return True
    return bool(re.fullmatch(r"https://[\w.-]+\.vercel\.app|http://(localhost|127\.0\.0\.1)(:\d+)?", o))


@router.get("/kakao/callback")
async def kakao_callback(code: str, request: Request, state: Optional[str] = None) -> RedirectResponse:
    """카카오 콜백: code→토큰→프로필→유저 생성→우리 JWT 발급→프론트로 리다이렉트."""
    if not settings.kakao_rest_api_key:
        raise HTTPException(status_code=400, detail="카카오 키 미설정")
    token_req = {
        "grant_type": "authorization_code",
        "client_id": settings.kakao_rest_api_key,
        "redirect_uri": _kakao_redirect_uri(request),  # authorize 때와 동일해야 함
        "code": code,
    }
    if settings.kakao_client_secret:  # 콘솔에서 클라이언트 시크릿 활성화 시 필수
        token_req["client_secret"] = settings.kakao_client_secret
    async with httpx.AsyncClient(timeout=10) as client:
        tok = await client.post(KAKAO_TOKEN, data=token_req)
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
    # SPA 로 토큰 전달 — state(=로그인 시작한 프론트 origin)가 있으면 그리로 복귀
    dest = state.rstrip("/") if state and _allowed_frontend(state) else settings.frontend_url.rstrip("/")
    if dest.startswith("pawdy://"):
        # 네이티브 앱: 크롬은 웹→커스텀스킴 자동 리다이렉트(302)를 차단하므로
        # HTML 인터스티셜(자동 시도 + '앱으로 돌아가기' 버튼=사용자 탭)로 딥링크를 연다.
        return HTMLResponse(_app_return_html(f"{dest}?token={token}"))
    return RedirectResponse(f"{dest}/?token={token}")


def _app_return_html(app_url: str) -> str:
    return (
        "<!doctype html><html lang='ko'><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width,initial-scale=1'>"
        "<title>Pawdy 로그인</title></head>"
        "<body style='margin:0;background:#FAF8F5;font-family:Pretendard,system-ui,sans-serif;"
        "display:flex;min-height:100vh;align-items:center;justify-content:center;'>"
        "<div style='text-align:center;padding:24px;'>"
        "<div style='font-size:26px;font-weight:800;color:#1A1714;letter-spacing:-1px;'>"
        "Pawdy<span style='color:#E8674A;'>.</span></div>"
        "<p style='color:#6E665E;font-size:14px;margin:14px 0 24px;'>로그인 완료! 앱으로 돌아갑니다.</p>"
        f"<a id='go' href='{app_url}' style='display:inline-block;background:#E8674A;color:#fff;"
        "text-decoration:none;padding:15px 30px;border-radius:15px;font-weight:800;font-size:15px;'>"
        "앱으로 돌아가기</a></div>"
        f"<script>var u=\"{app_url}\";location.href=u;"
        "setTimeout(function(){location.href=u;},500);</script>"
        "</body></html>"
    )


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
