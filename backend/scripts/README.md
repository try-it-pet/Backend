# Pawdy 감성 룩 LoRA 파인튜닝 (Replicate)

감성 룩(예: `winter`)을 **Flux LoRA**로 학습해 "진짜 Pawdy 느낌"으로 굳히는 과정.
학습 전까지는 백엔드가 **프롬프트 기반**으로 같은 룩을 생성하고(폴백), 학습이 끝나면
env 한 줄로 학습 모델로 교체된다. 코드 변경 없음.

## 전체 흐름
```
데이터셋 준비 → train_lora.py 로 학습 → 나온 모델 ref → PETFIT_LOOK_MODELS 등록 → 끝
```

## 1. 데이터셋 준비 (진짜 중요한 부분 = 브랜드 룩의 정의)

두 가지 방식 중 선택:

### A. 스타일 LoRA (간단, 추천 시작점)
- 목표 룩의 이미지 **15~30장**을 한 폴더에 모아 zip.
- "겨울 감성"이라면: 눈 배경·필름톤·감성 보정된 강아지 사진들. 초기엔
  현재 프롬프트 단계(gpt-image-2/kontext)로 뽑아 **잘 나온 컷만 큐레이션**해 시드로 써도 됨.
- 트리거 단어 1개 정하기(예: `PAWDYWINTER`) — 학습·생성에 동일 사용.
- 트레이너: `replicate/fast-flux-trainer` (기본값).

### B. Kontext 편집 LoRA (정체성 보존에 유리, 고급)
- **before/after 쌍 5~20개**: before=평범한 강아지 사진, after=감성 보정본, + 지시문.
- "이 변환을 배워라" 방식이라 입력 사진의 정체성을 잘 지킴 → 우리 피팅에 이상적.
- 트레이너를 Kontext 용으로 교체:
  ```bash
  export PETFIT_REPLICATE_TRAINER="replicate/fast-flux-kontext-trainer:<version>"
  ```
  (before/after 스키마는 해당 트레이너의 Replicate 페이지 참고 — `--input-key`,
   `--extra` 로 맞춘다.)

> 팁: A로 빠르게 파일럿 → 반응 보고 B로 품질/일관성 업그레이드.

## 2. 결과 모델(destination) 만들기
Replicate에서 빈 모델을 하나 만든다(웹 UI: New model, 또는 API). 예: `ljo1010/pawdy-winter`.

## 3. 학습 실행
```bash
cd backend
pip install replicate
export REPLICATE_API_TOKEN=r8_...

python scripts/train_lora.py \
  --look winter \
  --images ./data/winter.zip \
  --destination ljo1010/pawdy-winter \
  --trigger PAWDYWINTER \
  --steps 1000
```
- 비용: 이미지 ~20장/1000스텝 기준 **약 $2** (약 20분).
- 끝나면 `모델 ref` (`owner/name:version`)를 출력한다.

## 4. 백엔드에 등록 (env)
```bash
# 로컬 backend/.env 또는 Railway Variables
PETFIT_PROVIDER=replicate
PETFIT_REPLICATE_MODEL=black-forest-labs/flux-kontext-dev   # LoRA 가능한 오픈 버전
PETFIT_LOOK_MODELS={"winter": "ljo1010/pawdy-winter:abc123"}
PETFIT_LOOK_TRIGGERS={"winter": "PAWDYWINTER"}
```
이후 프론트에서 **모델=replicate + 감성 룩=겨울 감성**으로 생성하면 학습 LoRA 가 적용된다.
등록 안 한 룩은 자동으로 프롬프트 폴백.

## 5. 새 룩 추가
새 감성 룩(예: 벚꽃 `sakura`)은 **두 단계로 진화**한다(winter 와 동일 패턴):

1) **즉시(프롬프트 폴백)** — 코드에 등록만 하면 LoRA 없이 바로 동작한다.
   - 백엔드 `app/providers/looks.py`: `LOOK_PROMPTS` 에 아트디렉션 추가 + 장면(배경)을
     연출하는 룩이면 `SCENE_LOOKS` 에도 키 추가.
   - 프론트 `pawdy_flutter/lib/screens/fit_screen.dart` 의 `_styles` 에 `['sakura','벚꽃 감성']` 추가.
   - 이 상태면 replicate 폴백(kontext-pro + 프롬프트)으로 렌더된다.

2) **LoRA(선택, 고품질)** — 위 1~4 과정으로 그 룩 LoRA 를 학습 → `PETFIT_LOOK_LORAS`(가중치
   URL)·`PETFIT_LOOK_TRIGGERS` 에 키만 추가하면 코드 변경 없이 학습 모델로 승격된다. 실제
   상품 옷(ref_image)이 있는 상품이면 자동으로 **2단계 피팅**(multi-image 착용 → LoRA 룩)까지 적용.
