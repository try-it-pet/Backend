"""DB 테이블(SQLModel). 응답용 Pydantic 모델(models.py)과 분리 —
store.py 가 Row ↔ 도메인 모델(User/Pet/...) 변환을 담당한다.
"""

from datetime import datetime, timezone
from typing import Optional

from sqlmodel import Field, SQLModel


class UserRow(SQLModel, table=True):
    __tablename__ = "users"
    id: Optional[int] = Field(default=None, primary_key=True)
    provider: str
    nickname: str
    profile_image: Optional[str] = None
    kakao_id: Optional[str] = Field(default=None, index=True, unique=True)


class PetRow(SQLModel, table=True):
    __tablename__ = "pets"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    name: str
    species: str = "dog"
    breed: Optional[str] = None
    weight_kg: Optional[float] = None
    age: Optional[str] = None
    chest_cm: Optional[float] = None
    neck_cm: Optional[float] = None
    back_cm: Optional[float] = None


class LikeRow(SQLModel, table=True):
    __tablename__ = "likes"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    product_id: int


class CartRow(SQLModel, table=True):
    __tablename__ = "cart"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    product_id: int
    size: str = "M"
    qty: int = 1


class OrderRow(SQLModel, table=True):
    __tablename__ = "orders"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    items_json: str  # [{product_id,size,qty}, ...]
    total: int
    created_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    status: str = Field(default="결제완료")
    carrier: Optional[str] = Field(default=None, description="택배사")
    tracking_no: Optional[str] = Field(default=None, description="송장번호")




class ReviewRow(SQLModel, table=True):
    """상품 리뷰(별점 + 텍스트). 유저↔상품별 작성."""
    __tablename__ = "reviews"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    product_id: int = Field(index=True)
    rating: int = 5
    text: str = ""
    created_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    image: Optional[str] = Field(default=None, description="리뷰 첨부 이미지 URL")



class FittingRow(SQLModel, table=True):
    """AI 피팅 생성 이력(라이브러리). 성공한 생성만 유저별로 기록."""
    __tablename__ = "fittings"
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    product_id: int
    image_url: str
    kind: str = "tryon"  # tryon | fourcut
    style: Optional[str] = None
    created_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class UserCounterRow(SQLModel, table=True):
    """유저별 카운터: AI 생성 사용/보너스, 피팅 횟수."""
    __tablename__ = "user_counters"
    user_id: int = Field(primary_key=True)
    gen_used: int = 0
    gen_bonus: int = 0
    fittings: int = 0


class ResultRow(SQLModel, table=True):
    """생성 결과 이미지(인메모리 RAM 대신 DB 영구 저장). 추후 S3/CDN 이관 대상."""
    __tablename__ = "results"
    job_id: str = Field(primary_key=True)
    data: bytes
    mime: str = "image/png"
    created_at: float = 0.0


class KVRow(SQLModel, table=True):
    """전역 카운터 등(key→int). 예: gen_total(누적 생성 수)."""
    __tablename__ = "kv"
    key: str = Field(primary_key=True)
    ival: int = 0


class ShopRow(SQLModel, table=True):
    """상점/브랜드 정보"""
    __tablename__ = "shops"
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(index=True, unique=True)
    description: Optional[str] = None
    logo_url: Optional[str] = None
    owner_id: int = Field(index=True)
    created_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class ProductRow(SQLModel, table=True):
    """상품 정보 테이블"""
    __tablename__ = "products"
    id: Optional[int] = Field(default=None, primary_key=True)
    shop_id: Optional[int] = Field(default=None, index=True)
    brand: str
    name: str
    price: int
    fit: int = 90
    category: str = "fashion"
    species: str = "dog"
    fittable: bool = True
    image: Optional[str] = None
    ref_image: Optional[str] = None
    url: Optional[str] = None
    sizes_json: Optional[str] = None  # JSON string e.g. ["XS", "S", "M"]
    stock: int = Field(default=99, description="재고량")


