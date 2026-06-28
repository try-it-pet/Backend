from fastapi import APIRouter, HTTPException

from ..data import PRODUCTS, PRODUCTS_BY_ID
from ..models import Product

router = APIRouter(prefix="/products", tags=["products"])


@router.get("", response_model=list[Product])
def list_products() -> list[Product]:
    return PRODUCTS


@router.get("/{product_id}", response_model=Product)
def get_product(product_id: int) -> Product:
    product = PRODUCTS_BY_ID.get(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="product not found")
    return product
