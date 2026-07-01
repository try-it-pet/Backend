"""Pawdy '감성 룩' 레지스트리 — 프롬프트/구도/배경 프리셋 + 학습된 LoRA 매핑의 단일 출처.

룩 하나 = 완결형 아트디렉션(프롬프트). 시즌/트렌드에 따라 계속 추가한다.
각 룩은 2단계로 진화한다:
  1) 프롬프트 단계 — LOOK_PROMPTS 의 아트디렉션만으로 생성(지금 바로 가능).
  2) LoRA 단계 — 같은 룩을 Flux Kontext LoRA 로 파인튜닝 → PETFIT_LOOK_MODELS 에
     `{"winter": "user/pawdy-winter:<version>"}` 로 등록하면 그 학습 모델로 생성.
등록된 LoRA 모델이 있으면 그걸 쓰고, 없으면 프롬프트로 폴백한다(코드 변경 불필요).
"""

import json

from ..config import settings

# 사진풍/감성 룩 — 프론트 칩과 1:1 대응. 'winter' 같은 감성 룩은 장면(배경)까지 연출.
LOOK_PROMPTS = {
    "winter": (
        "Reimagine as a cinematic, emotional Korean 'winter feels' photo for social media: "
        "soft falling snow, a dreamy snowy forest or frozen-lake background, cool blue tones with a "
        "warm key light gently lit on the pet, soft film grain, shallow depth of field with bokeh, "
        "delicate rim backlight and a faint breath of cold air, soft pastel color grade. "
        "Keep it cozy, wistful and share-worthy"
    ),
    "studio": "clean catalog studio photo, even soft lighting, crisp focus",
    "lifestyle": "lifestyle photo at home or on a walk, natural ambient light, shallow depth of field",
    "film": "warm analog film look, soft grain, gentle highlights",
    "snap": "candid smartphone snapshot, natural daylight, relaxed everyday mood",
}

# 자체 장면(배경)을 연출하는 감성 룩 — BACKGROUND_PRESETS(studio/keep)를 덮어쓴다.
SCENE_LOOKS = {"winter"}

COMPOSITION_PRESETS = {
    "front_full": "front-facing full-body framing with the whole pet visible",
    "side": "side profile, full body in frame",
    "closeup": "close-up on the upper body and face, the garment clearly visible",
    "sitting": "the pet sitting in a three-quarter view, full body in frame",
}

BACKGROUND_PRESETS = {
    "studio": "Replace the background with a soft, clean studio backdrop.",
    "keep": "Preserve the original background and setting of the first image.",
}


def _look_models() -> dict[str, str]:
    """학습된 LoRA 모델 매핑. env PETFIT_LOOK_MODELS(JSON) 로 등록.

    예: PETFIT_LOOK_MODELS='{"winter": "ljo1010/pawdy-winter:abc123"}'
    """
    raw = settings.look_models_json
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        return {str(k): str(v) for k, v in data.items()} if isinstance(data, dict) else {}
    except (json.JSONDecodeError, TypeError):
        return {}


def look_model(style: str | None) -> str | None:
    """해당 룩에 학습된 Replicate 모델 ref(user/name:version). 없으면 None(프롬프트 폴백)."""
    if not style:
        return None
    return _look_models().get(style)


def look_trigger(style: str | None) -> str | None:
    """LoRA 학습 시 사용한 트리거 단어(있으면 프롬프트 앞에 붙임)."""
    if not style:
        return None
    raw = settings.look_triggers_json
    if not raw:
        return None
    try:
        data = json.loads(raw)
        return data.get(style) if isinstance(data, dict) else None
    except (json.JSONDecodeError, TypeError):
        return None
