from itertools import count
from typing import Dict, List, Tuple

from .models import CartItem, Order, Pet, TryOnJob, User

# 인메모리 저장소 (프로토타입). 실제로는 PostgreSQL/Redis/S3 로 교체.
USERS: Dict[int, User] = {}
KAKAO_TO_USER: Dict[str, int] = {}  # kakao_id -> user_id

PETS_BY_USER: Dict[int, List[Pet]] = {}
LIKES: Dict[int, set] = {}            # user_id -> {product_id}
CARTS: Dict[int, List[CartItem]] = {}  # user_id -> [CartItem]
ORDERS: Dict[int, List[Order]] = {}    # user_id -> [Order]
FITTINGS: Dict[int, int] = {}          # user_id -> AI 피팅 횟수

JOBS: Dict[str, TryOnJob] = {}
RESULTS: Dict[str, Tuple[bytes, str]] = {}  # job_id -> (image_bytes, mime)

_user_seq = count(1)
_pet_seq = count(1)
_cart_seq = count(1)
_order_seq = count(1)


def next_user_id() -> int:
    return next(_user_seq)


def next_pet_id() -> int:
    return next(_pet_seq)


def next_cart_id() -> int:
    return next(_cart_seq)


def next_order_id() -> int:
    return next(_order_seq)
