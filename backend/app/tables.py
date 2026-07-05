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
