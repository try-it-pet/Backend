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
    Product, Shop, ShopCreate, ProductCreate, ProductUpdate,
)

from .tables import (
    CartRow, FittingRow, KVRow, LikeRow, OrderRow, PetRow, ResultRow, ReviewRow,
    UserCounterRow, UserRow, ProductRow, ShopRow,
)

# ── 인메모리(단기 생성 상태만) ──
JOBS: Dict[str, object] = {}                       # job_id -> TryOnJob (폴링용, 단기)
GEN_RESERVED: Dict[str, Tuple[int, int]] = {}      # job_id -> (user_id, cost) 실패 시 환불
JOB_TS: Dict[str, float] = {}                       # job_id -> 생성 시각


# ── 변환 헬퍼 ──
def _user(r: UserRow) -> User:
    return User(id=r.id, provider=r.provider, nickname=r.nickname,
                profile_image=r.profile_image, kakao_id=r.kakao_id)


def _pet(r: PetRow) -> Pet:
    return Pet(id=r.id, name=r.name, species=r.species, breed=r.breed, weight_kg=r.weight_kg,
               age=r.age, chest_cm=r.chest_cm, neck_cm=r.neck_cm, back_cm=r.back_cm)


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


def find_pet(pet_id: Optional[int]) -> Optional[Pet]:
    if pet_id is None:
        return None
    with get_session() as s:
        r = s.get(PetRow, pet_id)
        return _pet(r) if r else None


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
def create_order(user_id: int) -> Optional[Order]:
    with get_session() as s:
        items = _cart_items(s, user_id)
        if not items:
            return None
        
        # 재고 검증 및 차감
        for it in items:
            p_row = s.get(ProductRow, it.product_id)
            if not p_row:
                raise ValueError(f"상품 정보를 찾을 수 없습니다: {it.product.name}")
            if p_row.stock < it.qty:
                raise ValueError(f"재고가 부족합니다: {it.product.name} (남은 재고: {p_row.stock}개)")
            p_row.stock -= it.qty
            s.add(p_row)

        total = sum(it.product.price * it.qty for it in items)
        payload = json.dumps([{"product_id": it.product_id, "size": it.size, "qty": it.qty} for it in items])
        row = OrderRow(user_id=user_id, items_json=payload, total=total)
        s.add(row)
        for cr in s.exec(select(CartRow).where(CartRow.user_id == user_id)).all():
            s.delete(cr)  # 주문 후 장바구니 비움
        s.commit(); s.refresh(row)
        return _order(s, row)



def _order(s, r: OrderRow) -> Order:
    items = []
    for it in json.loads(r.items_json):
        p_row = s.get(ProductRow, it["product_id"])
        if p_row:
            product = _product(p_row)
            items.append(CartItem(id=0, product=product, product_id=it["product_id"],
                                  size=it["size"], qty=it["qty"]))
    return Order(id=r.id, items=items, total=r.total, created_at=r.created_at, status=r.status)



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
               created_at=r.created_at)
        for r in rows
    ]


def add_review(user_id: int, body: ReviewCreate) -> Review:
    with get_session() as s:
        r = ReviewRow(user_id=user_id, product_id=body.product_id,
                      rating=body.rating, text=body.text.strip())
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


def update_order_status(order_id: int, status: str) -> Optional[Order]:
    with get_session() as s:
        r = s.get(OrderRow, order_id)
        if not r:
            return None
        r.status = status
        s.add(r); s.commit(); s.refresh(r)
        return _order(s, r)


