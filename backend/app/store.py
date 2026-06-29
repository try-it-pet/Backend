from itertools import count
from typing import Dict, Tuple

from .models import Pet, TryOnJob

# 인메모리 저장소 (프로토타입). 실제로는 PostgreSQL/Redis/S3 로 교체.
PETS: Dict[int, Pet] = {}
JOBS: Dict[str, TryOnJob] = {}
# job_id -> (image_bytes, mime) : 프로바이더가 바이트로 준 결과 이미지
RESULTS: Dict[str, Tuple[bytes, str]] = {}

_pet_seq = count(1)


def next_pet_id() -> int:
    return next(_pet_seq)
