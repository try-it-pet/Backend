"""AI 생성 횟수 제한(quota) — 요금 방어.

정책(config):
- gen_limit_enabled=False → 극초반 무제한(사용량만 집계).
- global_free_cap>0 이고 누적 생성 < cap → 아직 무제한(퀄리티/바이럴 검증 구간).
- 그 외 → 계정당 free_generations + 구매 시 purchase_bonus 만큼만 생성 가능.
"""

from typing import Optional

from .config import settings
from .store import GEN_BONUS, GEN_RESERVED, GEN_TOTAL, GEN_USED


def limits_active() -> bool:
    """지금 실제로 횟수 제한을 적용하는가?"""
    if not settings.gen_limit_enabled:
        return False
    if settings.global_free_cap and GEN_TOTAL["count"] < settings.global_free_cap:
        return False
    return True


def granted(user_id: int) -> int:
    return settings.free_generations + GEN_BONUS.get(user_id, 0)


def remaining(user_id: int) -> int:
    return max(0, granted(user_id) - GEN_USED.get(user_id, 0))


def status(user_id: Optional[int]) -> dict:
    """프론트 표시용 상태."""
    unlimited = not limits_active()
    if unlimited or user_id is None:
        return {"unlimited": unlimited, "remaining": None, "granted": None,
                "used": GEN_USED.get(user_id or -1, 0)}
    return {
        "unlimited": False,
        "remaining": remaining(user_id),
        "granted": granted(user_id),
        "used": GEN_USED.get(user_id, 0),
    }


def can_generate(user_id: Optional[int], cost: int) -> bool:
    if not limits_active():
        return True
    if user_id is None:
        return False
    return remaining(user_id) >= cost


def consume(job_id: str, user_id: Optional[int], cost: int) -> None:
    """생성 수락 시 차감(예약). 항상 누적 집계는 올린다. 실패 시 refund 로 되돌림."""
    GEN_TOTAL["count"] += cost
    if user_id is None:
        return
    if limits_active():
        GEN_USED[user_id] = GEN_USED.get(user_id, 0) + cost
        GEN_RESERVED[job_id] = (user_id, cost)


def refund(job_id: str) -> None:
    """생성 실패 시 차감분 환불."""
    item = GEN_RESERVED.pop(job_id, None)
    if not item:
        return
    user_id, cost = item
    GEN_USED[user_id] = max(0, GEN_USED.get(user_id, 0) - cost)
    GEN_TOTAL["count"] = max(0, GEN_TOTAL["count"] - cost)


def settle(job_id: str) -> None:
    """생성 성공 시 예약 확정(환불 대상에서 제거)."""
    GEN_RESERVED.pop(job_id, None)


def grant_purchase(user_id: int) -> None:
    """구매 1건당 purchase_bonus 만큼 생성 횟수 추가."""
    GEN_BONUS[user_id] = GEN_BONUS.get(user_id, 0) + settings.purchase_bonus
