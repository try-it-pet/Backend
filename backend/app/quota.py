"""AI 생성 횟수 제한(quota) — DB 백엔드(재시작에도 유지, 결제 우회 방지).

정책(config):
- gen_limit_enabled=False → 극초반 무제한(사용량만 집계).
- global_free_cap>0 이고 누적 생성 < cap → 아직 무제한(퀄리티/바이럴 검증 구간).
- 그 외 → 계정당 free_generations + 구매 시 purchase_bonus 만큼만 생성 가능.
"""

import time
from datetime import datetime, timezone
from typing import Dict, List, Optional

from .config import settings
from .store import (
    GEN_RESERVED, gen_add_bonus, gen_add_used, gen_counts, gen_sub_used, kv_add, kv_get,
)

_TOTAL = "gen_total"  # 전역 누적 생성 수(극초반 상한 판단)


# ── 생성비 방어: 전역 일일 상한(kill-switch) ──
def _day_key() -> str:
    return "gen_day_" + datetime.now(timezone.utc).strftime("%Y%m%d")


def daily_cap_reached() -> bool:
    cap = settings.daily_gen_cap
    return cap > 0 and kv_get(_day_key()) >= cap


def daily_inc(n: int = 1) -> None:
    kv_add(_day_key(), n)


# ── 생성비 방어: IP 분당 레이트리밋(인메모리 슬라이딩 윈도우) ──
_IP_HITS: Dict[str, List[float]] = {}


def ip_allowed(ip: Optional[str]) -> bool:
    per_min = settings.ip_rate_per_min
    if per_min <= 0 or not ip:
        return True
    now = time.time()
    hits = [t for t in _IP_HITS.get(ip, []) if t > now - 60]
    if len(hits) >= per_min:
        _IP_HITS[ip] = hits
        return False
    hits.append(now)
    _IP_HITS[ip] = hits
    return True


def limits_active() -> bool:
    if not settings.gen_limit_enabled:
        return False
    if settings.global_free_cap and kv_get(_TOTAL) < settings.global_free_cap:
        return False
    return True


def granted(user_id: int) -> int:
    used, bonus = gen_counts(user_id)
    return settings.free_generations + bonus


def remaining(user_id: int) -> int:
    used, bonus = gen_counts(user_id)
    return max(0, settings.free_generations + bonus - used)


def status(user_id: Optional[int]) -> dict:
    if not limits_active() or user_id is None:
        return {"unlimited": not limits_active(), "remaining": None, "granted": None,
                "used": gen_counts(user_id)[0] if user_id else 0}
    used, bonus = gen_counts(user_id)
    return {"unlimited": False, "remaining": max(0, settings.free_generations + bonus - used),
            "granted": settings.free_generations + bonus, "used": used}


def can_generate(user_id: Optional[int], cost: int) -> bool:
    if not limits_active():
        return True
    if user_id is None:
        return False
    return remaining(user_id) >= cost


def consume(job_id: str, user_id: Optional[int], cost: int) -> None:
    """생성 수락 시 차감(예약). 누적·일일 집계는 항상 올린다. 실패 시 refund 로 되돌림."""
    kv_add(_TOTAL, cost)
    daily_inc(cost)
    if user_id is None:
        return
    if limits_active():
        gen_add_used(user_id, cost)
        GEN_RESERVED[job_id] = (user_id, cost)


def refund(job_id: str) -> None:
    item = GEN_RESERVED.pop(job_id, None)
    if not item:
        return
    user_id, cost = item
    gen_sub_used(user_id, cost)
    kv_add(_TOTAL, -cost)


def settle(job_id: str) -> None:
    GEN_RESERVED.pop(job_id, None)


def grant_purchase(user_id: int) -> None:
    gen_add_bonus(user_id, settings.purchase_bonus)
