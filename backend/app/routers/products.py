import json
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Form, UploadFile

from ..auth import get_current_user
from ..data import CATEGORIES
from ..models import Product, ProductReviews, User, Shop, ShopCreate, ProductCreate, ProductUpdate, Order
from ..store import (
    list_product_reviews, product_rating, get_product as store_get_product,
    list_products as store_list_products, create_shop, get_shop_by_owner,
    create_product, list_seller_products, update_product, delete_product,
    list_seller_orders, update_order_status
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
    q: Optional[str] = None,
) -> list[Product]:
    items = store_list_products(category=category, q=q)
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
    stock: int = Form(99),
    image_file: UploadFile = File(...),
    ref_image_file: Optional[UploadFile] = File(None),
    user: User = Depends(get_current_user)
) -> Product:
    """판매자 상품 등록 API (Multipart form-data 지원)"""
    shop = get_shop_by_owner(user.id)
    if not shop:
        raise HTTPException(status_code=403, detail="Only shop owners can register products")

    # 대표 이미지 업로드 (용량·실이미지 검증 후 실제 포맷 기준 확장자/MIME 사용)
    from ..uploads import read_image_upload
    image_data, image_ext, image_mime = read_image_upload(image_file)
    image_key = f"products/{uuid.uuid4()}.{image_ext}"
    image_url = put_bytes(image_key, image_data, image_mime)

    if not image_url:
        raise HTTPException(status_code=500, detail="Failed to upload product image")

    # 피팅 레퍼런스 이미지 업로드
    ref_image_url = None
    if fittable:
        if ref_image_file:
            ref_image_data, ref_ext, ref_mime = read_image_upload(ref_image_file)
            ref_key = f"products/ref_{uuid.uuid4()}.{ref_ext}"
            ref_image_url = put_bytes(ref_key, ref_image_data, ref_mime)
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
        sizes=parsed_sizes,
        stock=stock
    )

    return create_product(
        shop_id=shop.id,
        brand=brand,
        body=product_create,
        image_url=image_url,
        ref_image_url=ref_image_url
    )




@router.get("/seller/my-products", response_model=list[Product])
def get_seller_products(user: User = Depends(get_current_user)) -> list[Product]:
    """판매자 등록 상품 목록 조회"""
    shop = get_shop_by_owner(user.id)
    if not shop:
        raise HTTPException(status_code=403, detail="No shop found for user")
    return list_seller_products(shop.id)


@router.put("/seller/products/{product_id}", response_model=Product)
def put_seller_product(product_id: int, body: ProductUpdate, user: User = Depends(get_current_user)) -> Product:
    """판매자 등록 상품 정보 수정"""
    shop = get_shop_by_owner(user.id)
    if not shop:
        raise HTTPException(status_code=403, detail="No shop found for user")
    # 수정 대상 상품 소유권 검증
    p = store_get_product(product_id)
    if not p or p.shop_id != shop.id:
        raise HTTPException(status_code=404, detail="Product not found or not owned by this shop")
    updated = update_product(product_id, body)
    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update product")
    return updated


@router.delete("/seller/products/{product_id}")
def delete_seller_product(product_id: int, user: User = Depends(get_current_user)) -> dict:
    """판매자 등록 상품 삭제"""
    shop = get_shop_by_owner(user.id)
    if not shop:
        raise HTTPException(status_code=403, detail="No shop found for user")
    p = store_get_product(product_id)
    if not p or p.shop_id != shop.id:
        raise HTTPException(status_code=404, detail="Product not found or not owned by this shop")
    success = delete_product(product_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to delete product")
    return {"status": "success", "message": "Product deleted"}


@router.get("/seller/my-orders", response_model=list[Order])
def get_seller_orders(user: User = Depends(get_current_user)) -> list[Order]:
    """자사 상품이 들어간 주문 목록 조회"""
    shop = get_shop_by_owner(user.id)
    if not shop:
        raise HTTPException(status_code=403, detail="No shop found for user")
    return list_seller_orders(shop.id)


@router.patch("/seller/orders/{order_id}/status", response_model=Order)
def patch_seller_order_status(
    order_id: int,
    status: str = Form(...),
    carrier: Optional[str] = Form(None),
    tracking_no: Optional[str] = Form(None),
    user: User = Depends(get_current_user)
) -> Order:
    """주문의 배송 상태 변경"""
    shop = get_shop_by_owner(user.id)
    if not shop:
        raise HTTPException(status_code=403, detail="No shop found for user")
    # 주문 내에 자사 상품이 들었는지 검증
    my_orders = list_seller_orders(shop.id)
    if not any(o.id == order_id for o in my_orders):
        raise HTTPException(status_code=404, detail="Order not found or contains no products from this shop")
    updated = update_order_status(order_id, status, carrier=carrier, tracking_no=tracking_no)
    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update order status")
    return updated



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
