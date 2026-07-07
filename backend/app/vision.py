import base64
import time

import anyio
import httpx

from .config import settings

# 주체 설명(캡션)에서 강아지/고양이로 볼 키워드. moondream 이 종/구어체로 답해도 잡히게 넉넉히.
_PET_WORDS = (
    "dog", "puppy", "pup", "doggo", "canine", "chihuahua", "poodle", "retriever", "terrier",
    "cat", "kitten", "kitty", "feline",
)

_PROMPT = (
    "What is the main subject of this photo? Answer in 3 to 5 words, "
    "for example: a small brown dog."
)


async def detect_pet(image_bytes: bytes) -> dict:
    """업로드 사진의 주체를 Replicate 경량 VLM(moondream2)으로 설명받아 강아지/고양이인지 판별.

    OpenAI 미사용(런타임 OpenAI 탈피). 반환: {"pet": bool, "subject": str}.
    토큰/모델 문제 등으로 판별 불가하면 차단하지 않고 통과(pet=True)시킨다.
    """
    if not settings.replicate_token:
        return {"pet": True, "subject": ""}
    try:
        import replicate
    except ImportError:
        return {"pet": True, "subject": ""}

    def _call() -> str:
        tok = settings.replicate_token
        headers = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}
        model = settings.pet_detect_model
        if ":" in model:  # owner/name:version
            version = model.split(":", 1)[1]
        else:  # 슬러그 → 최신 버전
            version = replicate.Client(api_token=tok).models.get(model).latest_version.id
        img = "data:image/png;base64," + base64.b64encode(image_bytes).decode()
        r = httpx.post("https://api.replicate.com/v1/predictions", headers=headers,
                       json={"version": version, "input": {"image": img, "prompt": _PROMPT}},
                       timeout=60)
        r.raise_for_status()
        pid = r.json()["id"]
        for _ in range(40):  # ~2분 (콜드스타트 포함)
            time.sleep(3)
            s = httpx.get(f"https://api.replicate.com/v1/predictions/{pid}",
                          headers=headers, timeout=30).json()
            st = s.get("status")
            if st == "succeeded":
                out = s.get("output")
                return "".join(out) if isinstance(out, list) else str(out or "")
            if st in ("failed", "canceled"):
                raise RuntimeError(s.get("error") or f"replicate {st}")
        raise RuntimeError("pet detect timeout")

    try:
        desc = (await anyio.to_thread.run_sync(_call)).strip()
        low = desc.lower()
        is_pet = any(w in low for w in _PET_WORDS)
        # subject 은 실패 안내문에만 쓰이므로 pet 이 아닐 때만 채운다(무엇을 봤는지 알려주기).
        return {"pet": is_pet, "subject": "" if is_pet else desc}
    except Exception:  # noqa: BLE001 (판별 실패 시 차단보다 진행)
        return {"pet": True, "subject": ""}
