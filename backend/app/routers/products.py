from typing import Optional

from fastapi import APIRouter, HTTPException

from ..data import CATEGORIES, PRODUCTS, PRODUCTS_BY_ID
from ..models import Product, ProductReviews
from ..store import list_product_reviews, product_rating

router = APIRouter(prefix="/products", tags=["products"])


@router.get("/categories")
def list_categories() -> list[dict]:
    """5 대분류 + 세부 항목 (Pawdy 기획서)."""
    return CATEGORIES


@router.get("", response_model=list[Product])
def list_products(
    category: Optional[str] = None,
    species: Optional[str] = None,
    min_price: Optional[int] = None,
    max_price: Optional[int] = None,
    fittable: Optional[bool] = None,
) -> list[Product]:
    items = PRODUCTS
    if category:
        items = [p for p in items if p.category == category]
    if species and species != "all":
        items = [p for p in items if p.species in (species, "all")]
    if min_price is not None:
        items = [p for p in items if p.price >= min_price]
    if max_price is not None:
        items = [p for p in items if p.price <= max_price]
    if fittable is not None:
        items = [p for p in items if p.fittable == fittable]
    return items


@router.get("/{product_id}", response_model=Product)
def get_product(product_id: int) -> Product:
    product = PRODUCTS_BY_ID.get(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="product not found")
    return product


@router.get("/{product_id}/reviews", response_model=ProductReviews)
def get_reviews(product_id: int) -> ProductReviews:
    """상품 리뷰 목록 + 평균 별점/개수 (공개)."""
    if product_id not in PRODUCTS_BY_ID:
        raise HTTPException(status_code=404, detail="product not found")
    count, average = product_rating(product_id)
    return ProductReviews(count=count, average=average, items=list_product_reviews(product_id))
