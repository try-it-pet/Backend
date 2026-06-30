import base64
import json

import anyio

from .config import settings


async def detect_pet(image_bytes: bytes) -> dict:
    """업로드 사진에 강아지/고양이가 있는지 OpenAI 비전으로 판별.

    반환: {"pet": bool, "subject": str}.
    키/모델 문제 등으로 판별 불가하면 차단하지 않고 통과(pet=True)시킨다.
    """
    if not settings.openai_api_key:
        return {"pet": True, "subject": ""}
    try:
        from openai import OpenAI
    except ImportError:
        return {"pet": True, "subject": ""}

    b64 = base64.b64encode(image_bytes).decode()

    def _call() -> str:
        client = OpenAI(api_key=settings.openai_api_key)
        resp = client.chat.completions.create(
            model=settings.vision_model,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": (
                                "Look at this photo. Is the main subject a real dog or cat (a pet)? "
                                'Reply ONLY compact JSON: {"pet": true or false, '
                                '"subject": "<2-4 Korean words for what you actually see>"}.'
                            ),
                        },
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                    ],
                }
            ],
            max_tokens=60,
            temperature=0,
        )
        return resp.choices[0].message.content or ""

    try:
        raw = await anyio.to_thread.run_sync(_call)
        s = raw.strip().strip("`")
        if s.lower().startswith("json"):
            s = s[4:].strip()
        data = json.loads(s)
        return {"pet": bool(data.get("pet")), "subject": str(data.get("subject") or "")}
    except Exception:  # noqa: BLE001 (판별 실패 시 차단보다 진행)
        return {"pet": True, "subject": ""}
