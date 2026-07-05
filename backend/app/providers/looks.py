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

# 일러스트/감성 룩 — 펫을 통째로 "다시 그림"(옷 착용 X). 프롬프트가 착장 base 를 대체.
# gpt-image-2(openai)에서 검증된 20대 트렌디 그림체. 하트·반짝이 없이 무드 팔레트.
ILLUSTRATION_LOOKS = {
    "ghibli": (
        "Redraw this exact pet as a soft dreamy anime-style illustration: gentle natural muted colors, "
        "delicate soft shading, cinematic calm mood, refined and tasteful, Studio-Ghibli-like warmth. "
        "No cutesy hearts or sparkles. Keep the pet recognizable (fur pattern, face, accessories)."
    ),
    "riso": (
        "Redraw this exact pet as a trendy risograph print illustration: grainy print texture, limited "
        "2-3 tone muted retro palette, flat shapes, modern zine aesthetic, stylish and minimal. "
        "No hearts or sparkles. Keep the pet recognizable (fur pattern, face, accessories)."
    ),
    "mood": (
        "Redraw this exact pet as a trendy minimal illustration for a 20s audience: clean subtle linework, "
        "muted sophisticated palette (cream, sage, dusty warm tones), flat matte finish, calm cool "
        "aesthetic, modern illustration-goods style. No hearts, no sparkles, no candy colors. "
        "Simple background. Keep the pet recognizable (fur pattern, face, accessories)."
    ),
}


def is_illustration(style: str | None) -> bool:
    return bool(style) and style in ILLUSTRATION_LOOKS

COMPOSITION_PRESETS = {
    "front_full": "front-facing full-body framing with the whole pet visible",
    "side": "side profile, full body in frame",
    "closeup": "close-up on the upper body and face, the garment clearly visible",
    "sitting": "the pet sitting in a three-quarter view, full body in frame",
    # 인생네컷(2x2) 4컷 포즈/표정 — 칩으로는 노출하지 않고 fourcut 플로우에서만 사용.
    "fc_front": "front-facing head-and-shoulders portrait, looking straight at the camera, alert and cute",
    "fc_tilt": "head tilted to one side, curious inquisitive expression, portrait framing",
    "fc_smile": "happy open-mouth smile with tongue slightly out, joyful, portrait framing",
    "fc_closeup": "extreme close-up of the face filling the frame, big sparkling eyes, playful 'face-cam' selfie feel",
}

# 인생네컷 2x2 순서·라벨 (한 장 사진 → 4컷). 라벨은 내부용/플레이스홀더 표기.
FOURCUT_POSES = [
    ("fc_front", "정면"),
    ("fc_tilt", "갸웃"),
    ("fc_smile", "활짝"),
    ("fc_closeup", "얼빡"),
]

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


def look_lora(style: str | None) -> str | None:
    """해당 룩에 학습된 LoRA 가중치 URL. 있으면 flux-kontext-dev-lora 추론에 얹는다."""
    if not style:
        return None
    raw = settings.look_loras_json
    if not raw:
        return None
    try:
        data = json.loads(raw)
        return data.get(style) if isinstance(data, dict) else None
    except (json.JSONDecodeError, TypeError):
        return None


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
