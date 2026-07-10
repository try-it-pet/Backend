from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class Product(BaseModel):
    id: int
    shop_id: Optional[int] = Field(None, description="상점 ID")
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
    stock: int = Field(99, description="재고량")


class ShopCreate(BaseModel):
    name: str
    description: Optional[str] = None


class Shop(ShopCreate):
    id: int
    logo_url: Optional[str] = None
    owner_id: int
    created_at: str


class ProductCreate(BaseModel):
    brand: str
    name: str
    price: int
    category: str = "fashion"
    species: str = "dog"
    fittable: bool = True
    url: Optional[str] = None
    sizes: Optional[list[str]] = None
    stock: int = Field(99, description="재고량")




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
    image: Optional[str] = None


class Pet(PetCreate):
    id: int



class User(BaseModel):
    id: int
    provider: str = Field(description="kakao | dev")
    nickname: str
    profile_image: Optional[str] = None
    kakao_id: Optional[str] = None
    email: Optional[str] = None
    google_id: Optional[str] = None



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
    status: str = "결제완료"
    carrier: Optional[str] = None
    tracking_no: Optional[str] = None
    buyer_name: Optional[str] = None
    payment_key: Optional[str] = None
    order_code: str = ""






class ProductUpdate(BaseModel):
    name: Optional[str] = None
    price: Optional[int] = None
    category: Optional[str] = None
    species: Optional[str] = None
    fittable: Optional[bool] = None
    url: Optional[str] = None
    sizes: Optional[list[str]] = None
    stock: Optional[int] = None



class Stats(BaseModel):
    orders: int
    likes: int
    fittings: int


class ReviewCreate(BaseModel):
    product_id: int
    rating: int = Field(5, ge=1, le=5, description="별점 1~5")
    text: str = ""


class Review(BaseModel):
    id: int
    product_id: int
    user_id: int
    nickname: str
    rating: int
    text: str
    created_at: str
    image: Optional[str] = None



class ProductReviews(BaseModel):
    count: int
    average: float = Field(description="평균 별점(소수1자리)")
    items: list[Review]


class Notification(BaseModel):
    id: int
    user_id: int
    title: str
    content: str
    is_read: bool
    created_at: str



class Fitting(BaseModel):
    id: int
    product_id: int
    image_url: str
    kind: str = "tryon"  # tryon | fourcut
    style: Optional[str] = None
    created_at: str


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
