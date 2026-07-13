"""데이터 접근 레이어 — DB(SQLite 로컬 / Postgres 배포) 백엔드.

라우터는 여기 함수만 호출한다(직접 dict 접근 X). Row ↔ 도메인 모델(models.py) 변환 담당.
잡(JOBS)·예약(GEN_RESERVED)만 인메모리(단기 생성 상태). 결과 이미지·유저·quota 는 DB 영구화.
"""

import json
import time
import json
from typing import Dict, List, Optional, Tuple

from sqlmodel import select

from .db import get_session
from .models import (
    CartItem, CartItemCreate, Fitting, Order, Pet, PetCreate, Review, ReviewCreate, User,
    Product, Shop, ShopCreate, ProductCreate, ProductUpdate, Notification,
)

from .tables import (
    CartRow, FittingRow, KVRow, LikeRow, OrderRow, PetRow, ResultRow, ReviewRow,
    UserCounterRow, UserRow, ProductRow, ShopRow, NotificationRow,
)


# ── 인메모리(단기 생성 상태만) ──
JOBS: Dict[str, object] = {}                       # job_id -> TryOnJob (폴링용, 단기)
GEN_RESERVED: Dict[str, Tuple[int, int]] = {}      # job_id -> (user_id, cost) 실패 시 환불
JOB_TS: Dict[str, float] = {}                       # job_id -> 생성 시각


# ── 변환 헬퍼 ──
def _user(r: UserRow) -> User:
    return User(
        id=r.id,
        provider=r.provider,
        nickname=r.nickname,
        profile_image=r.profile_image,
        kakao_id=r.kakao_id,
        email=r.email,
        google_id=r.google_id
    )



def _pet(r: PetRow) -> Pet:
    return Pet(id=r.id, name=r.name, species=r.species, breed=r.breed, weight_kg=r.weight_kg,
               age=r.age, chest_cm=r.chest_cm, neck_cm=r.neck_cm, back_cm=r.back_cm, image=r.image)



def _product(r: ProductRow) -> Product:
    sizes = json.loads(r.sizes_json) if r.sizes_json else None
    return Product(
        id=r.id,
        shop_id=r.shop_id,
        brand=r.brand,
        name=r.name,
        price=r.price,
        fit=r.fit,
        category=r.category,
        species=r.species,
        fittable=r.fittable,
        image=r.image,
        ref_image=r.ref_image,
        url=r.url,
        sizes=sizes,
        stock=r.stock
    )



def _shop(r: ShopRow) -> Shop:
    return Shop(
        id=r.id,
        name=r.name,
        description=r.description,
        logo_url=r.logo_url,
        owner_id=r.owner_id,
        created_at=r.created_at
    )



def _counter(s, user_id: int) -> UserCounterRow:
    c = s.get(UserCounterRow, user_id)
    if c is None:
        c = UserCounterRow(user_id=user_id)
        s.add(c)
    return c


# ── 유저 ──
def get_user(user_id: int) -> Optional[User]:
    with get_session() as s:
        r = s.get(UserRow, user_id)
        return _user(r) if r else None


def create_dev_user(nickname: str) -> User:
    with get_session() as s:
        r = UserRow(provider="dev", nickname=nickname)
        s.add(r); s.commit(); s.refresh(r)
        return _user(r)


def upsert_kakao_user(kakao_id: str, nickname: str, image: Optional[str]) -> User:
    with get_session() as s:
        r = s.exec(select(UserRow).where(UserRow.kakao_id == kakao_id)).first()
        if r is None:
            r = UserRow(provider="kakao", nickname=nickname, profile_image=image, kakao_id=kakao_id)
            s.add(r); s.commit(); s.refresh(r)
        return _user(r)


import hashlib

import bcrypt


def _legacy_hash(password: str) -> str:
    """구 방식(SHA-256 + 고정 salt) — 기존 가입자 검증·자동 마이그레이션 용도로만 유지."""
    salt = "pawdy_salt_secure_123"
    return hashlib.sha256((password + salt).encode("utf-8")).hexdigest()


def _hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def _verify_password(password: str, stored: Optional[str]) -> Tuple[bool, bool]:
    """(일치 여부, 레거시 해시였는지). 레거시 일치 시 호출부에서 bcrypt 로 재해시한다."""
    if not stored:
        return False, False
    if stored.startswith("$2"):  # bcrypt
        try:
            return bcrypt.checkpw(password.encode("utf-8"), stored.encode("utf-8")), False
        except ValueError:
            return False, False
    return stored == _legacy_hash(password), True  # 구 SHA-256 해시


def register_email_user(email: str, password_raw: str, nickname: str) -> User:
    with get_session() as s:
        exists = s.exec(select(UserRow).where(UserRow.email == email)).first()
        if exists:
            raise ValueError("이미 가입된 이메일 주소입니다.")
        r = UserRow(
            provider="email",
            email=email,
            password_hash=_hash_password(password_raw),
            nickname=nickname
        )
        s.add(r); s.commit(); s.refresh(r)
        return _user(r)

def authenticate_email_user(email: str, password_raw: str) -> Optional[User]:
    with get_session() as s:
        r = s.exec(select(UserRow).where(UserRow.email == email)).first()
        if r is None:
            return None
        ok, legacy = _verify_password(password_raw, r.password_hash)
        if not ok:
            return None
        if legacy:  # 구 해시 사용자는 로그인 성공 시점에 bcrypt 로 무중단 업그레이드
            r.password_hash = _hash_password(password_raw)
            s.add(r); s.commit(); s.refresh(r)
        return _user(r)

def upsert_google_user(google_id: str, nickname: str, image: Optional[str]) -> User:
    with get_session() as s:
        r = s.exec(select(UserRow).where(UserRow.google_id == google_id)).first()
        if r is None:
            r = UserRow(provider="google", nickname=nickname, profile_image=image, google_id=google_id)
            s.add(r); s.commit(); s.refresh(r)
        else:
            if image and not r.profile_image:
                r.profile_image = image
                s.add(r); s.commit(); s.refresh(r)
        return _user(r)



# ── 펫 ──
def list_pets(user_id: int) -> List[Pet]:
    with get_session() as s:
        rows = s.exec(select(PetRow).where(PetRow.user_id == user_id)).all()
        return [_pet(r) for r in rows]


def add_pet(user_id: int, body: PetCreate) -> Pet:
    with get_session() as s:
        r = PetRow(user_id=user_id, **body.model_dump())
        s.add(r); s.commit(); s.refresh(r)
        return _pet(r)


def delete_pet(user_id: int, pet_id: int) -> bool:
    with get_session() as s:
        r = s.exec(select(PetRow).where(PetRow.id == pet_id, PetRow.user_id == user_id)).first()
        if not r:
            return False
        s.delete(r)
        s.commit()
        return True



def find_pet(pet_id: Optional[int]) -> Optional[Pet]:
    if pet_id is None:
        return None
    with get_session() as s:
        r = s.get(PetRow, pet_id)
        return _pet(r) if r else None


def pet_belongs_to(user_id: int, pet_id: int) -> bool:
    """pet_id 가 해당 유저 소유인지 — 타인 펫 도용(IDOR) 방지용."""
    with get_session() as s:
        r = s.get(PetRow, pet_id)
        return bool(r and r.user_id == user_id)


# ── 좋아요 ──
def list_likes(user_id: int) -> List[int]:
    with get_session() as s:
        rows = s.exec(select(LikeRow.product_id).where(LikeRow.user_id == user_id)).all()
        return sorted(rows)


def toggle_like(user_id: int, product_id: int) -> Tuple[bool, List[int]]:
    with get_session() as s:
        existing = s.exec(
            select(LikeRow).where(LikeRow.user_id == user_id, LikeRow.product_id == product_id)
        ).first()
        if existing:
            s.delete(existing); liked = False
        else:
            s.add(LikeRow(user_id=user_id, product_id=product_id)); liked = True
        s.commit()
        ids = sorted(s.exec(select(LikeRow.product_id).where(LikeRow.user_id == user_id)).all())
        return liked, ids


def count_likes(user_id: int) -> int:
    with get_session() as s:
        return len(s.exec(select(LikeRow.id).where(LikeRow.user_id == user_id)).all())


# ── 장바구니 ──
def _cart_items(s, user_id: int) -> List[CartItem]:
    rows = s.exec(select(CartRow).where(CartRow.user_id == user_id)).all()
    out = []
    for r in rows:
        p_row = s.get(ProductRow, r.product_id)
        if p_row:
            product = _product(p_row)
            out.append(CartItem(id=r.id, product=product, product_id=r.product_id, size=r.size, qty=r.qty))
    return out


def get_cart(user_id: int) -> List[CartItem]:
    with get_session() as s:
        return _cart_items(s, user_id)


def add_cart(user_id: int, body: CartItemCreate) -> List[CartItem]:
    with get_session() as s:
        row = s.exec(select(CartRow).where(
            CartRow.user_id == user_id, CartRow.product_id == body.product_id, CartRow.size == body.size
        )).first()
        if row:
            row.qty += body.qty
        else:
            s.add(CartRow(user_id=user_id, product_id=body.product_id, size=body.size, qty=body.qty))
        s.commit()
        return _cart_items(s, user_id)


def remove_cart(user_id: int, item_id: int) -> List[CartItem]:
    with get_session() as s:
        row = s.get(CartRow, item_id)
        if row and row.user_id == user_id:
            s.delete(row); s.commit()
        return _cart_items(s, user_id)


# ── 주문 ──
# 결제 흐름은 create_pending_order → (토스 결제) → confirm_payment 단일 경로.
# (구) create_order(결제 없이 즉시 결제완료·재고차감·보너스)는 우회 결제 문제로 제거함.
def create_pending_order(user_id: int) -> Optional[Order]:
    with get_session() as s:
        items = _cart_items(s, user_id)
        if not items:
            return None
        
        # 재고 미리 체크
        for it in items:
            p_row = s.get(ProductRow, it.product_id)
            if not p_row:
                raise ValueError(f"상품 정보를 찾을 수 없습니다: {it.product.name}")
            if p_row.stock < it.qty:
                raise ValueError(f"재고가 부족합니다: {it.product.name} (남은 재고: {p_row.stock}개)")

        total = sum(it.product.price * it.qty for it in items)
        payload = json.dumps([{"product_id": it.product_id, "size": it.size, "qty": it.qty} for it in items])
        row = OrderRow(user_id=user_id, items_json=payload, total=total, status="결제대기")
        s.add(row)
        s.commit(); s.refresh(row)
        return _order(s, row)


def confirm_payment(user_id: int, order_id: int, payment_key: str, amount: int) -> Order:
    import base64
    import httpx
    from .config import Settings
    
    settings = Settings()
    
    with get_session() as s:
        row = s.get(OrderRow, order_id)
        if not row:
            raise ValueError("주문 정보를 찾을 수 없습니다.")
        if row.user_id != user_id:
            raise ValueError("권한이 없는 주문입니다.")
        if row.status != "결제대기":
            raise ValueError(f"이미 처리되었거나 처리할 수 없는 주문 상태입니다. (현재 상태: {row.status})")
        if row.total != amount:
            raise ValueError(f"결제 요청 금액({amount}원)이 주문 총액({row.total}원)과 일치하지 않습니다.")

        # 토스 페이먼츠 승인 연동
        secret_key = settings.toss_secret_key
        if secret_key:
            encoded_key = base64.b64encode(f"{secret_key}:".encode("utf-8")).decode("utf-8")
            headers = {
                "Authorization": f"Basic {encoded_key}",
                "Content-Type": "application/json"
            }
            body = {
                "paymentKey": payment_key,
                "orderId": str(order_id),
                "amount": amount
            }
            try:
                resp = httpx.post(
                    "https://api.tosspayments.com/v1/payments/confirm",
                    json=body,
                    headers=headers,
                    timeout=10.0
                )
                if resp.status_code != 200:
                    try:
                        error_data = resp.json()
                        err_msg = error_data.get("message", "토스 승인 실패")
                    except Exception:
                        err_msg = resp.text
                    raise ValueError(f"토스페이먼츠 승인 실패: {err_msg}")
            except Exception as e:
                if not isinstance(e, ValueError):
                    # 원문(내부 URL·스택 등) 노출 금지 — 서버 로그로만 남기고 사용자엔 일반 메시지.
                    import logging
                    logging.getLogger("pawdy.payment").warning("토스 통신 오류: %r", e)
                    raise ValueError("결제 처리 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.")
                raise
        else:
            print("[Warning] PETFIT_TOSS_SECRET_KEY가 설정되지 않아 로컬 테스트용 모의 승인(Mock Confirm) 처리합니다.")

        # 재고 최종 차감
        items_payload = json.loads(row.items_json)
        for it in items_payload:
            p_row = s.get(ProductRow, it["product_id"])
            if not p_row:
                raise ValueError(f"상품 정보를 찾을 수 없습니다.")
            if p_row.stock < it["qty"]:
                raise ValueError(f"재고가 부족합니다: {p_row.name} (남은 재고: {p_row.stock}개)")
            p_row.stock -= it["qty"]
            s.add(p_row)

        # 장바구니 비우기
        for cr in s.exec(select(CartRow).where(CartRow.user_id == user_id)).all():
            s.delete(cr)

        # 주문 업데이트 및 저장
        row.status = "결제완료"
        row.payment_key = payment_key
        s.add(row)

        # 알림 생성 (소비자)
        create_notification_in_session(
            s,
            user_id,
            "결제 승인 완료",
            f"토스페이먼츠를 통한 결제 승인이 정상 완료되었습니다. (주문번호 #{order_id})"
        )

        # 알림 생성 (각 상점 판매자)
        notified_sellers = set()
        for it in items_payload:
            p_row = s.get(ProductRow, it["product_id"])
            if p_row and p_row.shop_id:
                shop_row = s.get(ShopRow, p_row.shop_id)
                if shop_row and shop_row.owner_id and shop_row.owner_id not in notified_sellers:
                    create_notification_in_session(
                        s,
                        shop_row.owner_id,
                        "신규 주문 접수",
                        f"내 상점 '{shop_row.name}'에 신규 결제완료 주문(주문번호 #{order_id})이 접수되었습니다."
                    )
                    notified_sellers.add(shop_row.owner_id)

        # AI 생성 보너스 충전 — 같은 세션 내에서 처리(중첩 세션 시 SQLite 락/부분커밋 위험).
        _counter(s, user_id).gen_bonus += settings.purchase_bonus

        s.commit(); s.refresh(row)
        return _order(s, row)






def _order(s, r: OrderRow) -> Order:
    import hashlib
    items = []
    for it in json.loads(r.items_json):
        p_row = s.get(ProductRow, it["product_id"])
        if p_row:
            product = _product(p_row)
            items.append(CartItem(id=0, product=product, product_id=it["product_id"],
                                  size=it["size"], qty=it["qty"]))
    user_row = s.get(UserRow, r.user_id)
    buyer_name = user_row.nickname if user_row else "알 수 없음"

    # 주문 고유 식별 코드 생성 (예: P20260710-0015-E8A7)
    date_str = "00000000"
    if r.created_at:
        try:
            date_str = r.created_at.split("T")[0].replace("-", "")
        except Exception:
            pass
    hash_suffix = hashlib.md5(str(r.id).encode()).hexdigest()[:4].upper()
    order_code = f"P{date_str}-{r.id:04d}-{hash_suffix}"

    return Order(
        id=r.id,
        items=items,
        total=r.total,
        created_at=r.created_at,
        status=r.status,
        carrier=r.carrier,
        tracking_no=r.tracking_no,
        buyer_name=buyer_name,
        payment_key=r.payment_key,
        order_code=order_code
    )









def list_orders(user_id: int) -> List[Order]:
    with get_session() as s:
        rows = s.exec(select(OrderRow).where(OrderRow.user_id == user_id)).all()
        return [_order(s, r) for r in rows]


def count_orders(user_id: int) -> int:
    with get_session() as s:
        return len(s.exec(select(OrderRow.id).where(OrderRow.user_id == user_id)).all())


# ── 리뷰 ──
def _reviews(s, rows: List[ReviewRow]) -> List[Review]:
    """ReviewRow 목록 → 작성자 닉네임을 채운 Review 목록."""
    uids = {r.user_id for r in rows}
    nick = {}
    if uids:
        nick = {u.id: u.nickname for u in s.exec(select(UserRow).where(UserRow.id.in_(uids))).all()}
    return [
        Review(id=r.id, product_id=r.product_id, user_id=r.user_id,
               nickname=nick.get(r.user_id, "익명"), rating=r.rating, text=r.text,
               created_at=r.created_at, image=r.image)
        for r in rows
    ]


def add_review(user_id: int, product_id: int, rating: int, text: str, image_url: Optional[str] = None) -> Review:
    with get_session() as s:
        r = ReviewRow(user_id=user_id, product_id=product_id,
                      rating=rating, text=text.strip(), image=image_url)
        s.add(r); s.commit(); s.refresh(r)
        return _reviews(s, [r])[0]



def list_product_reviews(product_id: int) -> List[Review]:
    with get_session() as s:
        rows = s.exec(
            select(ReviewRow).where(ReviewRow.product_id == product_id).order_by(ReviewRow.id.desc())
        ).all()
        return _reviews(s, rows)


def list_my_reviews(user_id: int) -> List[Review]:
    with get_session() as s:
        rows = s.exec(
            select(ReviewRow).where(ReviewRow.user_id == user_id).order_by(ReviewRow.id.desc())
        ).all()
        return _reviews(s, rows)


def product_rating(product_id: int) -> Tuple[int, float]:
    """(리뷰 수, 평균 별점)."""
    with get_session() as s:
        ratings = s.exec(select(ReviewRow.rating).where(ReviewRow.product_id == product_id)).all()
        if not ratings:
            return 0, 0.0
        return len(ratings), round(sum(ratings) / len(ratings), 1)


# ── 알림 센터 ──
def create_notification_in_session(s, user_id: int, title: str, content: str) -> NotificationRow:
    r = NotificationRow(user_id=user_id, title=title, content=content)
    s.add(r)
    return r

def create_notification(user_id: int, title: str, content: str) -> Notification:
    with get_session() as s:
        r = create_notification_in_session(s, user_id, title, content)
        s.commit(); s.refresh(r)
        return Notification(id=r.id, user_id=r.user_id, title=r.title, content=r.content, is_read=r.is_read, created_at=r.created_at)

def list_notifications(user_id: int) -> List[Notification]:
    with get_session() as s:
        rows = s.exec(select(NotificationRow).where(NotificationRow.user_id == user_id).order_by(NotificationRow.id.desc())).all()
        return [
            Notification(id=r.id, user_id=r.user_id, title=r.title, content=r.content, is_read=r.is_read, created_at=r.created_at)
            for r in rows
        ]

def mark_notification_as_read(user_id: int, notif_id: int) -> bool:
    with get_session() as s:
        r = s.get(NotificationRow, notif_id)
        if not r or r.user_id != user_id:
            return False
        r.is_read = True
        s.add(r); s.commit()
        return True

def mark_all_notifications_as_read(user_id: int) -> bool:
    with get_session() as s:
        rows = s.exec(select(NotificationRow).where(NotificationRow.user_id == user_id, NotificationRow.is_read == False)).all()
        for r in rows:
            r.is_read = True
            s.add(r)
        s.commit()
        return True

def delete_notification(user_id: int, notif_id: int) -> bool:
    with get_session() as s:
        r = s.get(NotificationRow, notif_id)
        if not r or r.user_id != user_id:
            return False
        s.delete(r); s.commit()
        return True

def delete_all_notifications(user_id: int) -> bool:
    with get_session() as s:
        rows = s.exec(select(NotificationRow).where(NotificationRow.user_id == user_id)).all()
        for r in rows:
            s.delete(r)
        s.commit()
        return True


# ── AI 피팅 이력(라이브러리) ──
def add_fitting(user_id: int, product_id: int, image_url: str,
                kind: str = "tryon", style: Optional[str] = None) -> None:
    with get_session() as s:
        s.add(FittingRow(user_id=user_id, product_id=product_id,
                         image_url=image_url, kind=kind, style=style))
        s.commit()


def list_fittings(user_id: int) -> List[Fitting]:
    with get_session() as s:
        rows = s.exec(
            select(FittingRow).where(FittingRow.user_id == user_id).order_by(FittingRow.id.desc())
        ).all()
        return [
            Fitting(id=r.id, product_id=r.product_id, image_url=r.image_url,
                    kind=r.kind, style=r.style, created_at=r.created_at)
            for r in rows
        ]


# ── 카운터(피팅/quota) ──
def inc_fitting(user_id: int) -> None:
    with get_session() as s:
        c = _counter(s, user_id); c.fittings += 1; s.commit()


def get_fittings(user_id: int) -> int:
    with get_session() as s:
        c = s.get(UserCounterRow, user_id)
        return c.fittings if c else 0


def gen_counts(user_id: int) -> Tuple[int, int]:
    """(used, bonus)"""
    with get_session() as s:
        c = s.get(UserCounterRow, user_id)
        return (c.gen_used, c.gen_bonus) if c else (0, 0)


def gen_add_used(user_id: int, n: int) -> None:
    with get_session() as s:
        c = _counter(s, user_id); c.gen_used += n; s.commit()


def gen_sub_used(user_id: int, n: int) -> None:
    with get_session() as s:
        c = _counter(s, user_id); c.gen_used = max(0, c.gen_used - n); s.commit()


def gen_add_bonus(user_id: int, n: int) -> None:
    with get_session() as s:
        c = _counter(s, user_id); c.gen_bonus += n; s.commit()


# ── 전역 카운터(KV) ──
def kv_get(key: str) -> int:
    with get_session() as s:
        r = s.get(KVRow, key)
        return r.ival if r else 0


def kv_add(key: str, n: int) -> None:
    with get_session() as s:
        r = s.get(KVRow, key)
        if r is None:
            r = KVRow(key=key, ival=0); s.add(r)
        r.ival = max(0, r.ival + n); s.commit()


# ── 생성 결과 이미지(DB 영구) ──
def save_result(job_id: str, data: bytes, mime: str) -> str:
    """결과 이미지 저장 후 접근 URL 반환. R2 설정 시 R2 공개 URL, 아니면 DB + 내부 경로."""
    from .storage import configured, put_bytes

    if configured():
        ext = "png" if "png" in (mime or "") else "jpg"
        url = put_bytes(f"results/{job_id}.{ext}", data, mime)
        if url:
            return url  # R2 공개 URL 직접 사용
    with get_session() as s:  # DB 폴백
        r = s.get(ResultRow, job_id)
        if r:
            r.data, r.mime, r.created_at = data, mime, time.time()
        else:
            s.add(ResultRow(job_id=job_id, data=data, mime=mime, created_at=time.time()))
        s.commit()
    return f"/tryon/{job_id}/result"


def get_result(job_id: str) -> Optional[Tuple[bytes, str]]:
    with get_session() as s:
        r = s.get(ResultRow, job_id)
        return (r.data, r.mime) if r else None


# ── 잡 메모리 정리 + 오래된 결과 이미지 정리 ──
def track_job(job_id: str) -> None:
    JOB_TS[job_id] = time.time()


def prune_jobs(max_keep: int = 500, max_age_sec: int = 7200) -> int:
    now = time.time()
    drop = {j for j, ts in JOB_TS.items() if now - ts > max_age_sec}
    keep = sorted(((ts, j) for j, ts in JOB_TS.items() if j not in drop))
    if len(keep) > max_keep:
        drop.update(j for _, j in keep[: len(keep) - max_keep])
    for j in drop:
        JOBS.pop(j, None); JOB_TS.pop(j, None); GEN_RESERVED.pop(j, None)
    # 오래된 결과 이미지도 DB 에서 정리(하루 경과)
    if drop:
        cutoff = now - 86400
        with get_session() as s:
            for r in s.exec(select(ResultRow).where(ResultRow.created_at < cutoff)).all():
                s.delete(r)
            s.commit()
    return len(drop)


def get_product(product_id: int) -> Optional[Product]:
    with get_session() as s:
        r = s.get(ProductRow, product_id)
        return _product(r) if r else None


def list_products(category: Optional[str] = None, q: Optional[str] = None) -> List[Product]:
    with get_session() as s:
        stmt = select(ProductRow)
        if category:
            stmt = stmt.where(ProductRow.category == category)
        if q:
            keyword = f"%{q}%"
            # 상품명(name) 또는 브랜드명(brand) 검색 지원 (SQLite/Postgres 공용 LIKE 일치)
            stmt = stmt.where((ProductRow.name.like(keyword)) | (ProductRow.brand.like(keyword)))
        rows = s.exec(stmt).all()
        return [_product(r) for r in rows]


def get_shop(shop_id: int) -> Optional[Shop]:
    with get_session() as s:
        r = s.get(ShopRow, shop_id)
        return _shop(r) if r else None


def get_shop_by_owner(owner_id: int) -> Optional[Shop]:
    with get_session() as s:
        r = s.exec(select(ShopRow).where(ShopRow.owner_id == owner_id)).first()
        return _shop(r) if r else None


def create_shop(owner_id: int, body: ShopCreate) -> Shop:
    with get_session() as s:
        r = ShopRow(owner_id=owner_id, name=body.name, description=body.description)
        s.add(r); s.commit(); s.refresh(r)
        return _shop(r)


def create_product(shop_id: int, brand: str, body: ProductCreate, image_url: Optional[str] = None, ref_image_url: Optional[str] = None) -> Product:
    with get_session() as s:
        sizes_json = json.dumps(body.sizes) if body.sizes else None
        # 새로운 상품 생성 시 AI 핏 기본 점수로 95 부여
        r = ProductRow(
            shop_id=shop_id,
            brand=brand,
            name=body.name,
            price=body.price,
            fit=95,
            category=body.category,
            species=body.species,
            fittable=body.fittable,
            image=image_url,
            ref_image=ref_image_url,
            url=body.url,
            sizes_json=sizes_json,
            stock=body.stock
        )

        s.add(r); s.commit(); s.refresh(r)
        return _product(r)


def list_seller_products(shop_id: int) -> List[Product]:
    with get_session() as s:
        rows = s.exec(select(ProductRow).where(ProductRow.shop_id == shop_id)).all()
        return [_product(r) for r in rows]


def update_product(product_id: int, body: ProductUpdate) -> Optional[Product]:
    with get_session() as s:
        r = s.get(ProductRow, product_id)
        if not r:
            return None
        if body.name is not None:
            r.name = body.name
        if body.price is not None:
            r.price = body.price
        if body.category is not None:
            r.category = body.category
        if body.species is not None:
            r.species = body.species
        if body.fittable is not None:
            r.fittable = body.fittable
        if body.url is not None:
            r.url = body.url
        if body.sizes is not None:
            r.sizes_json = json.dumps(body.sizes) if body.sizes else None
        if body.stock is not None:
            r.stock = body.stock
        s.add(r); s.commit(); s.refresh(r)
        return _product(r)


def delete_product(product_id: int) -> bool:
    with get_session() as s:
        r = s.get(ProductRow, product_id)
        if not r:
            return False
        s.delete(r); s.commit()
        return True


def list_seller_orders(shop_id: int) -> List[Order]:
    with get_session() as s:
        # 내 상점에 속한 상품 ID 목록을 먼저 추출
        my_p_ids = set(s.exec(select(ProductRow.id).where(ProductRow.shop_id == shop_id)).all())
        if not my_p_ids:
            return []
        
        # 전체 주문 리스트에서 내 상품이 포함된 주문만 선별
        all_order_rows = s.exec(select(OrderRow).order_by(OrderRow.id.desc())).all()
        seller_orders = []
        for o_row in all_order_rows:
            items_data = json.loads(o_row.items_json)
            # 내 샵 제품이 주문 항목에 하나라도 들어있다면
            if any(it["product_id"] in my_p_ids for it in items_data):
                seller_orders.append(_order(s, o_row))
        return seller_orders


def update_order_status(order_id: int, status: str, carrier: Optional[str] = None, tracking_no: Optional[str] = None) -> Optional[Order]:
    with get_session() as s:
        r = s.get(OrderRow, order_id)
        if not r:
            return None
        r.status = status
        # 상태에 따라 배송 정보를 업데이트하거나 초기화(결제완료, 배송준비 상태)
        if status in ("결제완료", "배송준비중"):
            r.carrier = None
            r.tracking_no = None
        else:
            if carrier is not None:
                r.carrier = carrier
            if tracking_no is not None:
                r.tracking_no = tracking_no
        # 소비자(r.user_id)에게 알림 발송 트리거
        if status == "배송중":
            tracking_msg = f" ({carrier} - 송장: {tracking_no})" if carrier and tracking_no else ""
            create_notification_in_session(
                s,
                user_id=r.user_id,
                title="배송 시작 안내",
                content=f"주문하신 상품의 배송이 시작되었습니다!{tracking_msg}"
            )
        elif status == "배송완료":
            create_notification_in_session(
                s,
                user_id=r.user_id,
                title="배송 완료 안내",
                content="상품 배송이 완료되었습니다. 이용해 주셔서 감사합니다! 만족하셨다면 리뷰를 남겨주세요."
            )
        elif status == "구매확정":
            create_notification_in_session(
                s,
                user_id=r.user_id,
                title="구매 확정 완료",
                content=f"주문번호 #{r.id}번 상품들의 구매 확정이 완료되었습니다. 만족하셨다면 후기를 남겨주세요!"
            )


        s.add(r); s.commit(); s.refresh(r)
        return _order(s, r)




