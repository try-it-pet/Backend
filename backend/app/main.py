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
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"https://.*\.vercel\.app",  # 모든 Vercel 배포/프리뷰 도메인 허용
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
    return {
        "status": "ok",
        "default_provider": settings.provider,
        "providers": settings.configured_providers(),  # 키 설정 여부
    }


@app.get("/", tags=["meta"])
def root() -> dict:
    return {"name": "Pawdy API", "docs": "/docs", "provider": settings.provider}
