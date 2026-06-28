from abc import ABC, abstractmethod
from typing import Optional

from ..models import Pet, Product, TryOnResult


class TryOnProvider(ABC):
    """AI 가상 피팅 프로바이더 추상화.

    벤더 종속을 막기 위한 단일 인터페이스. Mock → 외부 try-on/inpainting API →
    자체 호스팅 모델로 교체하더라도 이 시그니처만 지키면 라우터는 그대로다.
    """

    name: str = "base"

    @abstractmethod
    async def generate(
        self,
        *,
        product: Product,
        size: str,
        pet: Optional[Pet] = None,
        pet_image: Optional[bytes] = None,
    ) -> TryOnResult:
        """펫 이미지 + 상품 → 옷 입힌 결과 이미지/핏 정보 생성."""
        raise NotImplementedError
