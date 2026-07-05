import asyncio
from typing import Optional
from uuid import uuid4

import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import Response

from ..auth import get_optional_user
from ..config import settings
from ..data import PRODUCTS_BY_ID
from ..fourcut import compose_2x2
from ..models import JobStatus, TryOnJob, TryOnResult, User
from ..providers import get_provider
from ..providers.looks import FOURCUT_POSES
from ..quota import can_generate, consume, daily_cap_reached, ip_allowed, limits_active, refund, settle
from ..store import JOBS, find_pet, get_result, inc_fitting, prune_jobs, save_result, track_job
from ..vision import detect_pet

router = APIRouter(prefix="/tryon", tags=["tryon"])


def _client_ip(request: Optional[Request]) -> Optional[str]:
    if request is None:
        return None
    fwd = request.headers.get("x-forwarded-for")  # Railway/프록시 뒤 실제 IP
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else None


def _quota_precheck(provider: Optional[str], user: Optional[User], cost: int,
                    request: Optional[Request] = None) -> int:
    """생성 전 방어: IP 레이트리밋 → 전역 일일 상한 → 계정 횟수. 통과 시 cost 반환(mock 0)."""
    prov = (provider or settings.provider or "mock").lower()
    if prov == "mock":
        return 0  # mock(데모)은 과금 없음 → 횟수 소모 안 함
    if not ip_allowed(_client_ip(request)):
        raise HTTPException(status_code=429, detail="요청이 너무 많아요. 잠시 후 다시 시도해주세요.")
    if daily_cap_reached():
        raise HTTPException(status_code=503, detail="오늘 AI 생성이 많아 잠시 쉬어가요. 잠시 후 다시 시도해주세요.")
    if limits_active():
        if user is None:
            raise HTTPException(status_code=401, detail="AI 생성은 로그인이 필요해요.")
        if not can_generate(user.id, cost):
            raise HTTPException(
                status_code=402,
                detail="무료 AI 생성 횟수를 모두 사용했어요. 상품을 구매하면 5회가 더 충전돼요.",
            )
    return cost


async def _process_job(job_id: str, pet_image: Optional[bytes]) -> None:
    """비동기 워커 시뮬레이션. 실제로는 Celery/BullMQ 큐로 분리."""
    job = JOBS[job_id]
    job.status = JobStatus.processing
    try:
        product = PRODUCTS_BY_ID[job.product_id]
        pet = find_pet(job.pet_id)
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
            save_result(job_id, out.image_bytes, out.image_mime or "image/png")
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
    finally:
        # 생성 성공이면 소모 확정, 실패면 차감 환불
        (settle if job.status == JobStatus.done else refund)(job_id)


async def _fetch_bytes(url: str) -> Optional[bytes]:
    """외부 호스팅(Replicate 등) 결과 URL → 바이트."""
    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as c:
            r = await c.get(url)
            return r.content if r.status_code == 200 else None
    except Exception:  # noqa: BLE001
        return None


async def _process_fourcut(job_id: str, pet_image: Optional[bytes]) -> None:
    """인생네컷: 한 장의 펫 사진 → 4가지 포즈/표정 컷 생성 → 2x2 합성."""
    job = JOBS[job_id]
    job.status = JobStatus.processing
    try:
        product = PRODUCTS_BY_ID[job.product_id]
        pet = find_pet(job.pet_id)
        provider = get_provider(job.provider)

        if provider.name != "mock":
            if pet_image is None:
                job.status = JobStatus.failed
                job.error = "인생네컷은 펫 사진이 필요해요. 사진을 추가해주세요."
                return
            if settings.openai_api_key:  # 강아지/고양이 사전 검증
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

        # 4컷 생성(포즈/표정만 다르게, 같은 감성 룩·옷). Replicate 429(rate limit) 방지를 위해
        # 동시성을 제한하고 429 는 백오프 재시도한다. mock 은 즉시 반환.
        sem = asyncio.Semaphore(2)

        async def _one_cut(pose_key: str):
            async with sem:
                for attempt in range(3):
                    try:
                        return await provider.generate(
                            product=product, size=job.size, pet=pet, pet_image=pet_image,
                            style=job.style, composition=pose_key,
                        )
                    except Exception as exc:  # noqa: BLE001
                        if "429" in str(exc) and attempt < 2:
                            await asyncio.sleep(6)
                            continue
                        raise

        outs = await asyncio.gather(
            *[_one_cut(pk) for pk, _ in FOURCUT_POSES], return_exceptions=True
        )

        cells: list[Optional[bytes]] = []
        for out in outs:
            if isinstance(out, BaseException) or out is None:
                cells.append(None)
            elif out.image_bytes is not None:
                cells.append(out.image_bytes)
            elif out.image_url:
                cells.append(await _fetch_bytes(out.image_url))
            else:
                cells.append(None)

        labels = [ko for _, ko in FOURCUT_POSES]
        png = await asyncio.to_thread(compose_2x2, cells, labels)
        save_result(job_id, png, "image/png")

        made = sum(1 for c in cells if c)
        job.result = TryOnResult(
            image_url=f"/tryon/{job_id}/result",
            fit_score=product.fit,
            recommended_size=job.size or "M",
            analysis=f"{pet.name if pet else '우리 아이'}의 인생네컷이 완성됐어요! ({made}/4컷)",
        )
        job.status = JobStatus.done
    except Exception as exc:  # noqa: BLE001
        job.status = JobStatus.failed
        job.error = str(exc)
    finally:
        (settle if job.status == JobStatus.done else refund)(job_id)


@router.post("", response_model=TryOnJob, status_code=202)
async def create_tryon(
    request: Request,
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
    cost = _quota_precheck(provider, user, 1, request)
    image_bytes = await pet_image.read() if pet_image is not None else None
    if user is not None:
        inc_fitting(user.id)

    job_id = uuid4().hex
    job = TryOnJob(
        id=job_id, status=JobStatus.queued, product_id=product_id,
        pet_id=pet_id, size=size, provider=provider,
        style=style, composition=composition, background=background,
    )
    JOBS[job_id] = job
    track_job(job_id)
    prune_jobs()
    if cost:
        consume(job_id, user.id if user else None, cost)
    asyncio.create_task(_process_job(job_id, image_bytes))
    return job


@router.post("/fourcut", response_model=TryOnJob, status_code=202)
async def create_fourcut(
    request: Request,
    product_id: int = Form(...),
    size: str = Form("M"),
    pet_id: Optional[int] = Form(None),
    provider: Optional[str] = Form(None, description="mock | openai | replicate"),
    style: Optional[str] = Form(None, description="감성 룩 (winter 등)"),
    pet_image: Optional[UploadFile] = File(None),
    user: Optional[User] = Depends(get_optional_user),
) -> TryOnJob:
    """인생네컷(2x2): 한 장의 펫 사진 → 4포즈/표정 컷 생성 → 2x2 합성. GET /tryon/{id} 폴링.

    구도는 고정 4컷(정면·갸웃·활짝·얼빡)이며 `style`(감성 룩)·상품 옷은 함께 반영된다.
    """
    if product_id not in PRODUCTS_BY_ID:
        raise HTTPException(status_code=404, detail="product not found")
    cost = _quota_precheck(provider, user, settings.fourcut_cost, request)
    image_bytes = await pet_image.read() if pet_image is not None else None
    if user is not None:
        inc_fitting(user.id)

    job_id = uuid4().hex
    job = TryOnJob(
        id=job_id, status=JobStatus.queued, product_id=product_id,
        pet_id=pet_id, size=size, provider=provider, style=style,
    )
    JOBS[job_id] = job
    track_job(job_id)
    prune_jobs()
    if cost:
        consume(job_id, user.id if user else None, cost)
    asyncio.create_task(_process_fourcut(job_id, image_bytes))
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
    item = get_result(job_id)
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
