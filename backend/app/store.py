from itertools import count
from typing import Dict

from .models import Pet, TryOnJob

# 인메모리 저장소 (프로토타입). 실제로는 PostgreSQL/Redis 로 교체.
PETS: Dict[int, Pet] = {}
JOBS: Dict[str, TryOnJob] = {}

_pet_seq = count(1)


def next_pet_id() -> int:
    return next(_pet_seq)
