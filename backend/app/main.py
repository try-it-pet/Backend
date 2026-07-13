from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import settings
from .db import init_db
from .routers import auth, me, products, tryon

app = FastAPI(
    title="Pawdy API",
    version="0.2.0",
    description="Pawdy — 펫 전문 멀티샵: 상품·펫·AI 가상 피팅(착용·배치) API (프로토타입).",
)


@app.on_event("startup")
def _startup() -> None:
    init_db()  # DB 테이블 생성(SQLite 로컬 / Postgres 배포)

app.add_middleware(
    CORSMiddleware,
    # https://localhost, capacitor://localhost = 모바일 앱(Capacitor WebView) 오리진.
    # 그 외 웹 오리진은 PETFIT_CORS_ORIGINS 에 정확한 도메인만 등록한다 —
    # (구) *.vercel.app 와일드카드는 임의의 타인 Vercel 앱까지 허용해서 제거함.
    allow_origins=[*settings.cors_origins, "https://localhost", "capacitor://localhost"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(products.router)
app.include_router(me.router)
app.include_router(tryon.router)

# 상품 이미지 등 정적 파일 (app/static → /static)
app.mount("/static", StaticFiles(directory=Path(__file__).resolve().parent / "static"), name="static")


@app.get("/health", tags=["meta"])
def health() -> dict:
    """공개 헬스체크(Railway 등) — 구성/키 상태는 노출하지 않는다.

    상세 진단(provider·db·storage 구성)은 배포 콘솔의 env·로그에서 확인.
    """
    from sqlalchemy import text

    from .db import engine

    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:  # noqa: BLE001
        db_ok = False
    return {"status": "ok" if db_ok else "degraded"}


@app.get("/", tags=["meta"])
def root() -> dict:
    return {"name": "Pawdy API", "docs": "/docs"}
