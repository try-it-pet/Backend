from fastapi import APIRouter, Depends, HTTPException

from ..auth import get_current_user
from ..models import (
    CartItem, CartItemCreate, Fitting, Order, Pet, PetCreate, Review, ReviewCreate, Stats, User,
)
from ..quota import grant_purchase, status as quota_status
from ..store import (
    add_cart, add_pet, add_review, count_likes, count_orders, create_order, get_cart, get_fittings,
    list_fittings, list_likes, list_my_reviews, list_orders, list_pets, remove_cart, toggle_like,
    get_product,
)

router = APIRouter(prefix="/me", tags=["me"], dependencies=[Depends(get_current_user)])


# ── 좋아요 ──
@router.get("/likes", response_model=list[int])
def get_likes(user: User = Depends(get_current_user)) -> list[int]:
    return list_likes(user.id)


@router.post("/likes/{product_id}")
def like(product_id: int, user: User = Depends(get_current_user)) -> dict:
    if get_product(product_id) is None:
        raise HTTPException(status_code=404, detail="product not found")
    liked, ids = toggle_like(user.id, product_id)
    return {"liked": liked, "likedIds": ids}


# ── 장바구니 ──
@router.get("/cart", response_model=list[CartItem])
def cart(user: User = Depends(get_current_user)) -> list[CartItem]:
    return get_cart(user.id)


@router.post("/cart", response_model=list[CartItem])
def cart_add(body: CartItemCreate, user: User = Depends(get_current_user)) -> list[CartItem]:
    if get_product(body.product_id) is None:
        raise HTTPException(status_code=404, detail="product not found")
    return add_cart(user.id, body)


@router.delete("/cart/{item_id}", response_model=list[CartItem])
def cart_remove(item_id: int, user: User = Depends(get_current_user)) -> list[CartItem]:
    return remove_cart(user.id, item_id)


# ── 주문 ──
@router.post("/orders", response_model=Order)
def checkout(user: User = Depends(get_current_user)) -> Order:
    order = create_order(user.id)
    if order is None:
        raise HTTPException(status_code=400, detail="장바구니가 비어 있습니다")
    grant_purchase(user.id)  # 구매 보상: AI 생성 횟수 추가 충전
    return order


@router.get("/orders", response_model=list[Order])
def orders(user: User = Depends(get_current_user)) -> list[Order]:
    return list_orders(user.id)


# ── 펫 프로필 ──
@router.get("/pets", response_model=list[Pet])
def pets(user: User = Depends(get_current_user)) -> list[Pet]:
    return list_pets(user.id)


@router.post("/pets", response_model=Pet, status_code=201)
def create_pet(body: PetCreate, user: User = Depends(get_current_user)) -> Pet:
    return add_pet(user.id, body)


# ── 리뷰 ──
@router.get("/reviews", response_model=list[Review])
def my_reviews(user: User = Depends(get_current_user)) -> list[Review]:
    return list_my_reviews(user.id)


@router.post("/reviews", response_model=Review, status_code=201)
def write_review(body: ReviewCreate, user: User = Depends(get_current_user)) -> Review:
    if get_product(body.product_id) is None:
        raise HTTPException(status_code=404, detail="product not found")
    return add_review(user.id, body)


# ── AI 피팅 이력(라이브러리) ──
@router.get("/fittings", response_model=list[Fitting])
def fittings(user: User = Depends(get_current_user)) -> list[Fitting]:
    return list_fittings(user.id)


# ── AI 생성 잔여 횟수 ──
@router.get("/generations")
def generations(user: User = Depends(get_current_user)) -> dict:
    return quota_status(user.id)


# ── 통계 (마이 화면) ──
@router.get("/stats", response_model=Stats)
def stats(user: User = Depends(get_current_user)) -> Stats:
    return Stats(orders=count_orders(user.id), likes=count_likes(user.id), fittings=get_fittings(user.id))
