#!/usr/bin/env python
"""Pawdy 감성 룩 LoRA 학습 — Replicate 파인튜닝 트리거.

한 룩(예: winter)의 학습 이미지 zip 을 Replicate 트레이너로 올려 LoRA 를 만든다.
학습이 끝나면 나온 모델 ref(`owner/name:version`)를 출력 → 이 값을 백엔드 env
PETFIT_LOOK_MODELS 에 등록하면, 그 룩이 프롬프트 대신 학습 모델로 생성된다.

사전 준비
---------
1) pip install replicate
2) export REPLICATE_API_TOKEN=r8_...            (또는 PETFIT_REPLICATE_TOKEN)
3) 학습 데이터 zip 준비 — scripts/README.md 의 데이터셋 가이드 참고.
   - 스타일 LoRA(단순): 목표 룩 이미지 15~30장을 한 폴더에 zip.
   - Kontext 편집 LoRA: before/after 쌍 + 지시문(트레이너 스키마에 맞춰).

사용 예
-------
  python scripts/train_lora.py \
    --look winter \
    --images ./data/winter.zip \
    --destination ljo1010/pawdy-winter \
    --trigger PAWDYWINTER \
    --steps 1000

  # 트레이너 버전은 env 로 교체(기본 fast-flux-trainer). Kontext 트레이너로 바꾸려면:
  #   export PETFIT_REPLICATE_TRAINER="replicate/fast-flux-kontext-trainer:<version>"

주의: 트레이너마다 input 키가 다르다(이 스크립트는 fast-flux-trainer 기준:
input_images/trigger_word/steps). 다른 트레이너면 --input-key 로 이미지 키를 맞추고,
필요한 추가 파라미터는 --extra 로 넘긴다. 각 트레이너 Replicate 페이지의 schema 확인.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path


def _token() -> str:
    # backend/.env 를 로드(app.config 와 동일). 그래야 PETFIT_REPLICATE_TOKEN 이 잡힘.
    try:
        from dotenv import load_dotenv

        load_dotenv(Path(__file__).resolve().parent.parent / ".env")
    except ImportError:
        pass
    tok = os.getenv("REPLICATE_API_TOKEN") or os.getenv("PETFIT_REPLICATE_TOKEN")
    if not tok:
        sys.exit("REPLICATE_API_TOKEN(또는 PETFIT_REPLICATE_TOKEN) 가 필요합니다.")
    return tok


def main() -> None:
    ap = argparse.ArgumentParser(description="Pawdy 감성 룩 LoRA 학습")
    ap.add_argument("--look", required=True, help="룩 키 (예: winter)")
    ap.add_argument("--images", required=True, help="학습 이미지 zip 경로(_start/_end 쌍)")
    ap.add_argument("--destination", required=True, help="결과 모델 owner/name")
    ap.add_argument("--instruction", default=None, help="Kontext 편집 지시문(기본: apply Pawdy <look> style)")
    ap.add_argument("--steps", type=int, default=1000)
    ap.add_argument("--trigger", default=None, help="(스타일 LoRA 전용) 트리거 단어")
    ap.add_argument(
        "--trainer",
        default=os.getenv(
            "PETFIT_REPLICATE_TRAINER",
            "replicate/fast-flux-kontext-trainer:"
            "26c877b4ec3988b7e8edc5840e61339c68f09913bb11e23c31566590fd92a66d",
        ),
        help="트레이너 모델:버전 (기본 = Kontext 편집 LoRA)",
    )
    ap.add_argument("--input-key", default="input_images", help="이미지 zip input 키")
    ap.add_argument("--steps-key", default="training_steps", help="스텝 수 input 키")
    ap.add_argument("--create-dest", action="store_true", help="destination 모델이 없으면 생성")
    ap.add_argument("--hardware", default="gpu-l40s", help="destination 추론 하드웨어(cpu|gpu-t4|gpu-l40s)")
    ap.add_argument("--extra", default="{}", help="추가 input(JSON 문자열)")
    args = ap.parse_args()

    os.environ.setdefault("REPLICATE_API_TOKEN", _token())
    try:
        import replicate
    except ImportError:
        sys.exit("replicate 패키지가 없습니다: pip install replicate")

    if not os.path.isfile(args.images):
        sys.exit(f"이미지 zip 을 찾을 수 없습니다: {args.images}")

    instruction = args.instruction or f"apply Pawdy {args.look} style"

    if args.create_dest:  # destination 모델이 없으면 생성(있으면 무시)
        owner, _, name = args.destination.partition("/")
        try:
            replicate.models.get(args.destination)
        except Exception:  # noqa: BLE001
            replicate.models.create(
                owner=owner, name=name, visibility="private", hardware=args.hardware
            )
            print(f"[train] destination 생성: {args.destination}")

    train_input: dict = {
        args.input_key: open(args.images, "rb"),
        args.steps_key: args.steps,
        "kontext_prompt_instruction": instruction,
    }
    if args.trigger:  # 스타일 LoRA 트레이너를 쓸 때만
        train_input["trigger_word"] = args.trigger
        train_input.pop("kontext_prompt_instruction", None)
    train_input.update(json.loads(args.extra))

    print(f"[train] look={args.look} trainer={args.trainer} → {args.destination}")
    training = replicate.trainings.create(
        destination=args.destination,
        version=args.trainer,
        input=train_input,
    )
    print(f"[train] started: {training.id}  (https://replicate.com/p/{training.id})")

    # 폴링 — 보통 수십 분 이내. 창을 닫아도 Replicate 대시보드에서 진행 확인 가능.
    while training.status not in ("succeeded", "failed", "canceled"):
        time.sleep(15)
        training.reload()
        print(f"[train] status={training.status}")

    if training.status != "succeeded":
        sys.exit(f"[train] 학습 실패: {training.status}\n{training.error or ''}")

    out = training.output or {}
    version = out.get("version") if isinstance(out, dict) else None
    model_ref = version or f"{args.destination}:<확인필요>"
    print("\n[train] 완료!")
    print(f"  모델 ref: {model_ref}")
    print("  백엔드에 등록(Railway Variables / backend .env):")
    print(f'    PETFIT_LOOK_MODELS=\'{{"{args.look}": "{model_ref}"}}\'')
    trig = args.trigger or instruction
    print(f'    PETFIT_LOOK_TRIGGERS=\'{{"{args.look}": "{trig}"}}\'')


if __name__ == "__main__":
    main()
