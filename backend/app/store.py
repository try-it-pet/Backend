import time
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

# AI 생성 횟수 제한(quota). remaining = free_generations + GEN_BONUS - GEN_USED
GEN_USED: Dict[int, int] = {}     # user_id -> 사용한 생성 횟수
GEN_BONUS: Dict[int, int] = {}    # user_id -> 구매 등으로 추가 부여된 횟수
GEN_TOTAL: Dict[str, int] = {"count": 0}  # 전역 누적 생성 수(극초반 상한 판단용)
GEN_RESERVED: Dict[str, Tuple[int, int]] = {}  # job_id -> (user_id, cost) 실패 시 환불용

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


# ── 잡/결과 메모리 정리(프로토타입 인메모리 저장의 OOM 방지) ──
# 실서비스에서는 S3/CDN + DB 로 이관해야 함. 그 전까지는 오래된/초과분을 정리.
JOB_TS: Dict[str, float] = {}  # job_id -> 생성 시각


def track_job(job_id: str) -> None:
    JOB_TS[job_id] = time.time()


def prune_jobs(max_keep: int = 500, max_age_sec: int = 7200) -> int:
    """오래됐거나(2h) 개수 초과(500) 잡·결과·예약을 제거해 RAM 무한 증가를 막는다."""
    now = time.time()
    drop = {j for j, ts in JOB_TS.items() if now - ts > max_age_sec}
    keep = sorted(((ts, j) for j, ts in JOB_TS.items() if j not in drop))
    if len(keep) > max_keep:
        drop.update(j for _, j in keep[: len(keep) - max_keep])
    for j in drop:
        JOBS.pop(j, None)
        RESULTS.pop(j, None)
        JOB_TS.pop(j, None)
        GEN_RESERVED.pop(j, None)
    return len(drop)
