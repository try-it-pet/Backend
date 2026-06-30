import asyncio
from typing import Optional
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import Response

from ..auth import get_optional_user
from ..config import settings
from ..data import PRODUCTS_BY_ID
from ..models import JobStatus, TryOnJob, TryOnResult, User
from ..providers import get_provider
from ..store import FITTINGS, JOBS, PETS_BY_USER, RESULTS
from ..vision import detect_pet

router = APIRouter(prefix="/tryon", tags=["tryon"])


async def _process_job(job_id: str, pet_image: Optional[bytes]) -> None:
    """비동기 워커 시뮬레이션. 실제로는 Celery/BullMQ 큐로 분리."""
    job = JOBS[job_id]
    job.status = JobStatus.processing
    try:
        product = PRODUCTS_BY_ID[job.product_id]
        pet = None
        if job.pet_id is not None:
            for plist in PETS_BY_USER.values():
                pet = next((p for p in plist if p.id == job.pet_id), None)
                if pet:
                    break
        provider = get_provider(job.provider)

        # 실제 모델: 강아지/고양이 사진인지 사전 검증 → 아니면 이유를 담아 친절히 실패
        if provider.name != "mock" and pet_image is not None and settings.openai_api_key:
            check = await detect_pet(pet_image)
            if not check.get("pet"):
                subj = check.get("subject")
                job.status = JobStatus.failed
                job.error = (
                    "사진에서 강아지나 고양이를 찾지 못했어요"
                    + (f" ({subj})" if subj else "")
                    + ". 반려동물이 또렷하게 나온 정면 사진으로 다시 시도해주세요."
                )
                return

        # mock 은 즉시 반환되므로 지연을 흉내 내 로딩 UX 를 검증
        if provider.name == "mock":
            await asyncio.sleep(1.5)

        out = await provider.generate(
            product=product, size=job.size, pet=pet, pet_image=pet_image,
            style=job.style, composition=job.composition, background=job.background,
        )

        if out.image_bytes is not None:
            RESULTS[job_id] = (out.image_bytes, out.image_mime or "image/png")
            image_url = f"/tryon/{job_id}/result"
        elif out.image_url:
            image_url = out.image_url  # 외부 호스팅(Replicate 등)
        else:
            image_url = f"/tryon/{job_id}/preview.svg"  # mock

        job.result = TryOnResult(
            image_url=image_url,
            fit_score=out.fit_score,
            recommended_size=out.recommended_size,
            analysis=out.analysis,
        )
        job.status = JobStatus.done
    except Exception as exc:  # noqa: BLE001
        job.status = JobStatus.failed
        job.error = str(exc)


@router.post("", response_model=TryOnJob, status_code=202)
async def create_tryon(
    product_id: int = Form(...),
    size: str = Form("M"),
    pet_id: Optional[int] = Form(None),
    provider: Optional[str] = Form(None, description="mock | openai | replicate (비교용 override)"),
    style: Optional[str] = Form(None, description="studio | lifestyle | film | snap (사진풍)"),
    composition: Optional[str] = Form(None, description="front_full | side | closeup | sitting (구도)"),
    background: Optional[str] = Form(None, description="studio(교체) | keep(원본 유지)"),
    pet_image: Optional[UploadFile] = File(None),
    user: Optional[User] = Depends(get_optional_user),
) -> TryOnJob:
    """펫 이미지 + 상품 → 피팅 잡 생성(비동기). 결과는 GET /tryon/{id} 로 폴링.

    `provider` 로 요청마다 모델을 바꿔 같은 입력의 품질을 비교할 수 있다.
    로그인 상태면 마이 화면 'AI 피팅' 통계에 집계된다.
    """
    if product_id not in PRODUCTS_BY_ID:
        raise HTTPException(status_code=404, detail="product not found")
    image_bytes = await pet_image.read() if pet_image is not None else None
    if user is not None:
        FITTINGS[user.id] = FITTINGS.get(user.id, 0) + 1

    job_id = uuid4().hex
    job = TryOnJob(
        id=job_id, status=JobStatus.queued, product_id=product_id,
        pet_id=pet_id, size=size, provider=provider,
        style=style, composition=composition, background=background,
    )
    JOBS[job_id] = job
    asyncio.create_task(_process_job(job_id, image_bytes))
    return job


@router.get("/{job_id}", response_model=TryOnJob)
def get_job(job_id: str) -> TryOnJob:
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    return job


@router.get("/{job_id}/result")
def job_result(job_id: str) -> Response:
    """프로바이더가 바이트로 준 결과 이미지(OpenAI 등)."""
    item = RESULTS.get(job_id)
    if item is None:
        raise HTTPException(status_code=404, detail="result image not found")
    data, mime = item
    return Response(content=data, media_type=mime)


@router.get("/{job_id}/preview.svg")
def job_preview(job_id: str) -> Response:
    """Mock 결과 이미지(SVG). 실제 프로바이더는 생성된 래스터 이미지/URL을 반환."""
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    product = PRODUCTS_BY_ID.get(job.product_id)
    name = product.name if product else "상품"
    score = job.result.fit_score if job.result else "—"
    size = job.result.recommended_size if job.result else job.size
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="390" height="488" viewBox="0 0 390 488">
  <rect width="390" height="488" rx="22" fill="#F1ECE6"/>
  <text x="195" y="220" font-family="Pretendard,system-ui,sans-serif" font-size="13" fill="#A89F95" text-anchor="middle">AI 피팅 결과 (mock)</text>
  <text x="195" y="252" font-family="Pretendard,system-ui,sans-serif" font-size="15" font-weight="700" fill="#1A1714" text-anchor="middle">{name}</text>
  <text x="195" y="300" font-family="Pretendard,system-ui,sans-serif" font-size="40" font-weight="800" fill="#E8674A" text-anchor="middle">{score}%</text>
  <text x="195" y="328" font-family="Pretendard,system-ui,sans-serif" font-size="13" fill="#6E665E" text-anchor="middle">AI 핏 스코어 · 추천 사이즈 {size}</text>
</svg>"""
    return Response(content=svg, media_type="image/svg+xml")
