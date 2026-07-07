from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional

from ..models import Pet, Product


@dataclass
class ProviderOutput:
    """프로바이더 생성 결과(내부). 라우터가 image_url/저장 처리로 변환한다.

    이미지는 둘 중 하나로 전달:
    - image_bytes (+ image_mime): 직접 바이트(OpenAI 등) → 서버가 저장·서빙
    - image_url: 외부 호스팅 URL(Replicate 등) → 그대로 사용
    둘 다 없으면 라우터가 mock SVG 로 대체.
    """

    fit_score: int
    recommended_size: str
    analysis: str
    image_bytes: Optional[bytes] = None
    image_mime: Optional[str] = None
    image_url: Optional[str] = None


class TryOnProvider(ABC):
    """AI 가상 피팅 프로바이더 추상화.

    벤더 종속을 막기 위한 단일 인터페이스. mock / openai / replicate 가 모두
    이 시그니처를 구현하므로 라우터·프론트는 프로바이더와 무관하게 동작한다.
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
        style: Optional[str] = None,
        composition: Optional[str] = None,
        background: Optional[str] = None,
        seed: Optional[int] = None,
        worn: bool = False,
    ) -> ProviderOutput:
        """펫 이미지 + 상품 → 옷 입힌 결과(이미지/핏 정보) 생성.

        style/composition/background 는 구도·사진풍 프리셋 키(프로바이더가 지원 시 반영).
        seed 는 재현/일관성용. worn=True 면 pet_image 가 이미 대상 옷을 입은 상태(옷 착용 단계
        생략, 룩·포즈만 적용) — 인생네컷에서 실제 옷을 1번만 입히고 컷을 파생시킬 때 쓴다.
        """
        raise NotImplementedError
