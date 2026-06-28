from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class Product(BaseModel):
    id: int
    brand: str
    name: str
    price: int
    fit: int = Field(description="AI 핏 점수(%) — fit>=93 이면 'AI 추천' 라벨")


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
    result: Optional[TryOnResult] = None
    error: Optional[str] = None
