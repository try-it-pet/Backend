from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import pets, products, tryon

app = FastAPI(
    title="PetFit API",
    version="0.1.0",
    description="반려동물 AI 쇼핑 — 상품·펫·AI 가상 피팅 API (프로토타입, mock 프로바이더).",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(products.router)
app.include_router(pets.router)
app.include_router(tryon.router)


@app.get("/health", tags=["meta"])
def health() -> dict:
    return {"status": "ok", "provider": settings.provider}


@app.get("/", tags=["meta"])
def root() -> dict:
    return {"name": "PetFit API", "docs": "/docs", "provider": settings.provider}
