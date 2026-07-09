import json
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Form, UploadFile

from ..auth import get_current_user
from ..data import CATEGORIES
from ..models import Product, ProductReviews, User, Shop, ShopCreate, ProductCreate
from ..store import (
    list_product_reviews, product_rating, get_product as store_get_product,
    list_products as store_list_products, create_shop, get_shop_by_owner,
    create_product
)
from ..storage import put_bytes

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
    items = store_list_products(category=category)
    if species and species != "all":
        items = [p for p in items if p.species in (species, "all")]
    if min_price is not None:
        items = [p for p in items if p.price >= min_price]
    if max_price is not None:
        items = [p for p in items if p.price <= max_price]
    if fittable is not None:
        items = [p for p in items if p.fittable == fittable]
    return items


@router.post("/shops", response_model=Shop)
def register_shop(body: ShopCreate, user: User = Depends(get_current_user)) -> Shop:
    """상점 신규 개설"""
    existing = get_shop_by_owner(user.id)
    if existing:
        raise HTTPException(status_code=400, detail="User already owns a shop")
    return create_shop(user.id, body)


@router.get("/shops/me", response_model=Optional[Shop])
def get_my_shop(user: User = Depends(get_current_user)) -> Optional[Shop]:
    """내 상점 조회"""
    return get_shop_by_owner(user.id)


@router.post("", response_model=Product)
def register_product(
    brand: str = Form(...),
    name: str = Form(...),
    price: int = Form(...),
    category: str = Form("fashion"),
    species: str = Form("dog"),
    fittable: bool = Form(True),
    url: Optional[str] = Form(None),
    sizes: Optional[str] = Form(None),  # JSON list string e.g. '["XS", "S", "M"]'
    image_file: UploadFile = File(...),
    ref_image_file: Optional[UploadFile] = File(None),
    user: User = Depends(get_current_user)
) -> Product:
    """판매자 상품 등록 API (Multipart form-data 지원)"""
    shop = get_shop_by_owner(user.id)
    if not shop:
        raise HTTPException(status_code=403, detail="Only shop owners can register products")

    # 대표 이미지 업로드
    image_data = image_file.file.read()
    image_ext = image_file.filename.split(".")[-1] if "." in image_file.filename else "jpg"
    image_key = f"products/{uuid.uuid4()}.{image_ext}"
    image_url = put_bytes(image_key, image_data, image_file.content_type)

    if not image_url:
        raise HTTPException(status_code=500, detail="Failed to upload product image")

    # 피팅 레퍼런스 이미지 업로드
    ref_image_url = None
    if fittable:
        if ref_image_file:
            ref_image_data = ref_image_file.file.read()
            ref_ext = ref_image_file.filename.split(".")[-1] if "." in ref_image_file.filename else "jpg"
            ref_key = f"products/ref_{uuid.uuid4()}.{ref_ext}"
            ref_image_url = put_bytes(ref_key, ref_image_data, ref_image_file.content_type)
        else:
            # fittable 상품이나 ref_image가 없으면 대표 이미지를 피팅 이미지로 기본 사용
            ref_image_url = image_url

    parsed_sizes = None
    if sizes:
        try:
            parsed_sizes = json.loads(sizes)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid sizes format. Must be JSON list of strings.")

    product_create = ProductCreate(
        brand=brand,
        name=name,
        price=price,
        category=category,
        species=species,
        fittable=fittable,
        url=url,
        sizes=parsed_sizes
    )

    return create_product(
        shop_id=shop.id,
        brand=brand,
        body=product_create,
        image_url=image_url,
        ref_image_url=ref_image_url
    )


@router.get("/{product_id}", response_model=Product)
def get_product(product_id: int) -> Product:
    product = store_get_product(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="product not found")
    return product


@router.get("/{product_id}/reviews", response_model=ProductReviews)
def get_reviews(product_id: int) -> ProductReviews:
    """상품 리뷰 목록 + 평균 별점/개수 (공개)."""
    if store_get_product(product_id) is None:
        raise HTTPException(status_code=404, detail="product not found")
    count, average = product_rating(product_id)
    return ProductReviews(count=count, average=average, items=list_product_reviews(product_id))
