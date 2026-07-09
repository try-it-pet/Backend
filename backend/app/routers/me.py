from fastapi import APIRouter, Depends, HTTPException, Form, File, UploadFile
from pydantic import BaseModel
from typing import Optional


from ..auth import get_current_user
from ..models import (
    CartItem, CartItemCreate, Fitting, Order, Pet, PetCreate, Review, Stats, User, Notification,
)
from ..quota import grant_purchase, status as quota_status
from ..store import (
    add_cart, add_pet, add_review, count_likes, count_orders, create_order, get_cart, get_fittings,
    list_fittings, list_likes, list_my_reviews, list_orders, list_pets, remove_cart, toggle_like,
    get_product, list_notifications, mark_notification_as_read, mark_all_notifications_as_read,
    delete_notification, delete_all_notifications, delete_pet, create_pending_order, confirm_payment,

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


@router.post("/orders/pending", response_model=Order)
def checkout_pending(user: User = Depends(get_current_user)) -> Order:
    try:
        order = create_pending_order(user.id)
        if order is None:
            raise HTTPException(status_code=400, detail="장바구니가 비어 있습니다")
        return order
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


class PaymentConfirmRequest(BaseModel):
    paymentKey: str
    orderId: int
    amount: int


@router.post("/payments/confirm", response_model=Order)
def payments_confirm(req: PaymentConfirmRequest, user: User = Depends(get_current_user)) -> Order:
    try:
        order = confirm_payment(
            user_id=user.id,
            order_id=req.orderId,
            payment_key=req.paymentKey,
            amount=req.amount
        )
        return order
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))



@router.get("/orders", response_model=list[Order])
def orders(user: User = Depends(get_current_user)) -> list[Order]:
    return list_orders(user.id)


# ── 펫 프로필 ──
@router.get("/pets", response_model=list[Pet])
def pets(user: User = Depends(get_current_user)) -> list[Pet]:
    return list_pets(user.id)


@router.post("/pets", response_model=Pet, status_code=201)
def create_pet(
    name: str = Form(...),
    species: str = Form("dog"),
    breed: Optional[str] = Form(None),
    weight_kg: Optional[float] = Form(None),
    age: Optional[str] = Form(None),
    chest_cm: Optional[float] = Form(None),
    neck_cm: Optional[float] = Form(None),
    back_cm: Optional[float] = Form(None),
    image_file: Optional[UploadFile] = File(None),
    user: User = Depends(get_current_user)
) -> Pet:
    image_url = None
    if image_file:
        import uuid
        from ..storage import put_bytes
        image_data = image_file.file.read()
        image_ext = image_file.filename.split(".")[-1] if "." in image_file.filename else "jpg"
        image_key = f"pets/{uuid.uuid4()}.{image_ext}"
        image_url = put_bytes(image_key, image_data, image_file.content_type)
        if not image_url:
            raise HTTPException(status_code=500, detail="Failed to upload pet profile image")

    body = PetCreate(
        name=name,
        species=species,
        breed=breed,
        weight_kg=weight_kg,
        age=age,
        chest_cm=chest_cm,
        neck_cm=neck_cm,
        back_cm=back_cm,
        image=image_url
    )
    return add_pet(user.id, body)


@router.delete("/pets/{pet_id}")
def delete_my_pet(pet_id: int, user: User = Depends(get_current_user)) -> dict:
    success = delete_pet(user.id, pet_id)
    if not success:
        raise HTTPException(status_code=404, detail="Pet not found or access denied")
    return {"status": "success"}


# ── 리뷰 ──

@router.get("/reviews", response_model=list[Review])
def my_reviews(user: User = Depends(get_current_user)) -> list[Review]:
    return list_my_reviews(user.id)


@router.post("/reviews", response_model=Review, status_code=201)
def write_review(
    product_id: int = Form(...),
    rating: int = Form(5),
    text: str = Form(""),
    image_file: Optional[UploadFile] = File(None),
    user: User = Depends(get_current_user)
) -> Review:
    if get_product(product_id) is None:
        raise HTTPException(status_code=404, detail="product not found")

    image_url = None
    if image_file:
        import uuid
        from ..storage import put_bytes
        image_data = image_file.file.read()
        image_ext = image_file.filename.split(".")[-1] if "." in image_file.filename else "jpg"
        image_key = f"reviews/{uuid.uuid4()}.{image_ext}"
        image_url = put_bytes(image_key, image_data, image_file.content_type)
        if not image_url:
            raise HTTPException(status_code=500, detail="Failed to upload review image")

    return add_review(user_id=user.id, product_id=product_id, rating=rating, text=text, image_url=image_url)



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


# ── 알림 센터 ──
@router.get("/notifications", response_model=list[Notification])
def get_notifications(user: User = Depends(get_current_user)) -> list[Notification]:
    return list_notifications(user.id)


@router.post("/notifications/{notif_id}/read")
def read_notification(notif_id: int, user: User = Depends(get_current_user)) -> dict:
    success = mark_notification_as_read(user.id, notif_id)
    if not success:
        raise HTTPException(status_code=404, detail="Notification not found or access denied")
    return {"status": "success"}


@router.post("/notifications/read-all")
def read_all_notifications(user: User = Depends(get_current_user)) -> dict:
    mark_all_notifications_as_read(user.id)
    return {"status": "success"}


@router.delete("/notifications/{notif_id}")
def delete_one_notification(notif_id: int, user: User = Depends(get_current_user)) -> dict:
    success = delete_notification(user.id, notif_id)
    if not success:
        raise HTTPException(status_code=404, detail="Notification not found or access denied")
    return {"status": "success"}


@router.delete("/notifications")
def clear_all_notifications(user: User = Depends(get_current_user)) -> dict:
    delete_all_notifications(user.id)
    return {"status": "success"}

