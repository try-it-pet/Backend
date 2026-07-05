from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException

from ..auth import get_current_user
from ..data import PRODUCTS_BY_ID
from ..models import (
    CartItem, CartItemCreate, Order, Pet, PetCreate, Stats, User,
)
from ..quota import grant_purchase, status as quota_status
from ..store import (
    CARTS, FITTINGS, LIKES, ORDERS, PETS_BY_USER,
    next_cart_id, next_order_id, next_pet_id,
)

router = APIRouter(prefix="/me", tags=["me"], dependencies=[Depends(get_current_user)])


# ── 좋아요 ──
@router.get("/likes", response_model=list[int])
def list_likes(user: User = Depends(get_current_user)) -> list[int]:
    return sorted(LIKES.get(user.id, set()))


@router.post("/likes/{product_id}")
def toggle_like(product_id: int, user: User = Depends(get_current_user)) -> dict:
    if product_id not in PRODUCTS_BY_ID:
        raise HTTPException(status_code=404, detail="product not found")
    s = LIKES.setdefault(user.id, set())
    liked = product_id not in s
    s.add(product_id) if liked else s.discard(product_id)
    return {"liked": liked, "likedIds": sorted(s)}


# ── 장바구니 ──
@router.get("/cart", response_model=list[CartItem])
def get_cart(user: User = Depends(get_current_user)) -> list[CartItem]:
    return CARTS.get(user.id, [])


@router.post("/cart", response_model=list[CartItem])
def add_cart(body: CartItemCreate, user: User = Depends(get_current_user)) -> list[CartItem]:
    product = PRODUCTS_BY_ID.get(body.product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="product not found")
    cart = CARTS.setdefault(user.id, [])
    for it in cart:  # 같은 상품+사이즈면 수량만 증가
        if it.product_id == body.product_id and it.size == body.size:
            it.qty += body.qty
            return cart
    cart.append(CartItem(id=next_cart_id(), product=product, **body.model_dump()))
    return cart


@router.delete("/cart/{item_id}", response_model=list[CartItem])
def remove_cart(item_id: int, user: User = Depends(get_current_user)) -> list[CartItem]:
    cart = CARTS.get(user.id, [])
    CARTS[user.id] = [it for it in cart if it.id != item_id]
    return CARTS[user.id]


# ── 주문 ──
@router.post("/orders", response_model=Order)
def checkout(user: User = Depends(get_current_user)) -> Order:
    cart = CARTS.get(user.id, [])
    if not cart:
        raise HTTPException(status_code=400, detail="장바구니가 비어 있습니다")
    total = sum(it.product.price * it.qty for it in cart)
    order = Order(
        id=next_order_id(), items=list(cart), total=total,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    ORDERS.setdefault(user.id, []).append(order)
    CARTS[user.id] = []  # 주문 후 장바구니 비움
    grant_purchase(user.id)  # 구매 보상: AI 생성 횟수 추가 충전
    return order


@router.get("/orders", response_model=list[Order])
def list_orders(user: User = Depends(get_current_user)) -> list[Order]:
    return ORDERS.get(user.id, [])


# ── 펫 프로필 ──
@router.get("/pets", response_model=list[Pet])
def list_pets(user: User = Depends(get_current_user)) -> list[Pet]:
    return PETS_BY_USER.get(user.id, [])


@router.post("/pets", response_model=Pet, status_code=201)
def create_pet(body: PetCreate, user: User = Depends(get_current_user)) -> Pet:
    pet = Pet(id=next_pet_id(), **body.model_dump())
    PETS_BY_USER.setdefault(user.id, []).append(pet)
    return pet


# ── AI 생성 잔여 횟수 ──
@router.get("/generations")
def generations(user: User = Depends(get_current_user)) -> dict:
    """남은 AI 생성 횟수(무제한 모드면 unlimited=true)."""
    return quota_status(user.id)


# ── 통계 (마이 화면) ──
@router.get("/stats", response_model=Stats)
def stats(user: User = Depends(get_current_user)) -> Stats:
    return Stats(
        orders=len(ORDERS.get(user.id, [])),
        likes=len(LIKES.get(user.id, set())),
        fittings=FITTINGS.get(user.id, 0),
    )
