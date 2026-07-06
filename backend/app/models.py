from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class Product(BaseModel):
    id: int
    brand: str
    name: str
    price: int
    fit: int = Field(description="AI 핏/매치 점수(%) — fit>=93 이면 'AI 추천' 라벨")
    category: str = Field("fashion", description="care|fashion|active|wellness|home")
    species: str = Field("dog", description="dog|cat|all")
    fittable: bool = Field(True, description="AI 피팅(착용/배치) 가능 여부")
    image: Optional[str] = Field(None, description="상품 카드 이미지 URL/경로")
    ref_image: Optional[str] = Field(None, description="옷 레퍼런스 이미지 URL — AI 피팅이 이 옷을 입힘")
    url: Optional[str] = Field(None, description="원 판매처(해외직구) 상품 페이지 링크")
    sizes: Optional[list[str]] = Field(None, description="선택 가능 사이즈 목록 — 없으면 Free(단일 사이즈) 품목")


class PetCreate(BaseModel):
    name: str
    species: str = Field("dog", description="dog | cat | rabbit")
    breed: Optional[str] = None
    weight_kg: Optional[float] = None
    age: Optional[str] = None
    # 신체 치수 (사이즈 추천에 사용)
    chest_cm: Optional[float] = None
    neck_cm: Optional[float] = None
    back_cm: Optional[float] = None


class Pet(PetCreate):
    id: int


class User(BaseModel):
    id: int
    provider: str = Field(description="kakao | dev")
    nickname: str
    profile_image: Optional[str] = None
    kakao_id: Optional[str] = None


class AuthResult(BaseModel):
    token: str
    user: User


class CartItemCreate(BaseModel):
    product_id: int
    size: str = "M"
    qty: int = 1


class CartItem(CartItemCreate):
    id: int
    product: Product


class Order(BaseModel):
    id: int
    items: list[CartItem]
    total: int
    created_at: str


class Stats(BaseModel):
    orders: int
    likes: int
    fittings: int


class JobStatus(str, Enum):
    queued = "queued"
    processing = "processing"
    done = "done"
    failed = "failed"


class TryOnResult(BaseModel):
    image_url: str = Field(description="생성된 피팅 결과 이미지 URL")
    fit_score: int = Field(description="AI 핏 스코어(%)")
    recommended_size: str
    analysis: str


class TryOnJob(BaseModel):
    id: str
    status: JobStatus
    product_id: int
    pet_id: Optional[int] = None
    size: str = "M"
    provider: Optional[str] = Field(None, description="mock | openai | replicate (비교용)")
    style: Optional[str] = Field(None, description="studio | lifestyle | film | snap (사진풍)")
    composition: Optional[str] = Field(None, description="front_full | side | closeup | sitting (구도)")
    background: Optional[str] = Field(None, description="studio(교체) | keep(원본 유지)")
    result: Optional[TryOnResult] = None
    error: Optional[str] = None
