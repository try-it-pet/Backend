from typing import Optional

from ..models import Pet, Product
from .base import ProviderOutput, TryOnProvider


def recommend_size(pet: Optional[Pet]) -> str:
    """체중 기반 간단 사이즈 추천 (실제로는 둘레 실측 기반 표)."""
    if pet and pet.weight_kg is not None:
        w = pet.weight_kg
        if w < 3:
            return "S"
        if w < 6:
            return "M"
        if w < 9:
            return "L"
        return "XL"
    return "M"


class MockProvider(TryOnProvider):
    """실제 생성 없이 결정적 더미 결과를 반환. 종단 플로우 검증용.

    image_bytes/image_url 을 비워두면 라우터가 SVG placeholder 로 대체한다.
    """

    name = "mock"

    async def generate(
        self,
        *,
        product: Product,
        size: str,
        pet: Optional[Pet] = None,
        pet_image: Optional[bytes] = None,
    ) -> ProviderOutput:
        rec = size or recommend_size(pet)
        pet_name = pet.name if pet else "우리 아이"
        analysis = (
            f"{pet_name}의 체형에는 {rec} 사이즈가 가장 잘 맞아요. "
            f"목둘레가 여유로워 활동성이 좋고, 어깨선이 자연스럽게 떨어집니다."
        )
        return ProviderOutput(fit_score=product.fit, recommended_size=rec, analysis=analysis)
