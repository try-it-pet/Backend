#!/usr/bin/env python
"""Pawdy 감성 룩 Kontext LoRA 학습 — fal.ai 버전 (Replicate 트레이너 OOM 대체).

fal.ai `flux-kontext-trainer`는 Replicate 와 동일한 데이터셋 형식(INDEX_start/INDEX_end
+ INDEX.txt)을 쓰므로 build_dataset.py 로 만든 zip 을 그대로 재사용한다.
결과로 나온 LoRA 가중치 URL 을 백엔드 추론에 등록한다.

사전 준비:
  1) pip install fal-client
  2) FAL_KEY 발급(https://fal.ai/dashboard/keys) 후:
       - backend/.env 에 PETFIT_FAL_KEY=... 추가, 또는
       - 환경변수 FAL_KEY=... 설정
     (fal.ai 결제/크레딧도 설정돼 있어야 함)

사용:
  cd backend
  python scripts/train_lora_fal.py --look winter \
    --images "C:/Users/이재욱/Downloads/winter26_1024.zip" --steps 1000

출력된 LoRA URL 을 백엔드 추론에 등록:
  - Replicate 추론 모델 `black-forest-labs/flux-kontext-dev-lora` 의 lora_weights 로 사용,
    또는 fal.ai `fal-ai/flux-kontext-lora` 추론에 사용.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path


def _load_env_key() -> str:
    try:
        from dotenv import load_dotenv

        load_dotenv(Path(__file__).resolve().parent.parent / ".env")
    except ImportError:
        pass
    key = os.getenv("FAL_KEY") or os.getenv("PETFIT_FAL_KEY")
    if not key:
        sys.exit("FAL_KEY(또는 PETFIT_FAL_KEY) 가 필요합니다. https://fal.ai/dashboard/keys")
    os.environ["FAL_KEY"] = key  # fal_client 는 FAL_KEY 를 읽음
    return key


def _extract_lora_url(result: dict) -> str | None:
    """fal 결과에서 LoRA 파일 URL 을 최대한 찾아낸다(스키마 변동 대비)."""
    for k in ("diffusers_lora_file", "lora_file", "safetensors_file"):
        v = result.get(k)
        if isinstance(v, dict) and v.get("url"):
            return v["url"]
    # 혹시 중첩/다른 키
    for v in result.values():
        if isinstance(v, dict) and str(v.get("url", "")).endswith(".safetensors"):
            return v["url"]
    return None


def main() -> None:
    ap = argparse.ArgumentParser(description="Pawdy Kontext LoRA 학습 (fal.ai)")
    ap.add_argument("--look", required=True, help="룩 키 (예: winter)")
    ap.add_argument("--images", required=True, help="학습 zip (INDEX_start/INDEX_end 쌍)")
    ap.add_argument("--steps", type=int, default=1000)
    ap.add_argument("--instruction", default=None, help="편집 지시문(기본: apply Pawdy <look> style)")
    args = ap.parse_args()

    _load_env_key()
    try:
        import fal_client
    except ImportError:
        sys.exit("fal-client 가 없습니다: pip install fal-client")

    if not os.path.isfile(args.images):
        sys.exit(f"zip 을 찾을 수 없습니다: {args.images}")
    instruction = args.instruction or f"apply Pawdy {args.look} style"

    print(f"[fal] 업로드: {args.images}", flush=True)
    data_url = fal_client.upload_file(args.images)

    # subscribe 는 환경에 따라 hang 나므로 submit + 폴링으로 처리(관측 가능).
    app = "fal-ai/flux-kontext-trainer"
    handle = fal_client.submit(
        app,
        arguments={
            "image_data_url": data_url,
            "steps": args.steps,
            "default_caption": instruction,
        },
    )
    print(f"[fal] 학습 시작: request_id={handle.request_id}", flush=True)
    while True:
        st = fal_client.status(app, handle.request_id, with_logs=False)
        if type(st).__name__ == "Completed":
            break
        print(f"[fal] status={type(st).__name__}", flush=True)
        time.sleep(15)
    result = fal_client.result(app, handle.request_id)

    print("\n[fal] 완료. 결과:")
    print(json.dumps(result, indent=2, ensure_ascii=False)[:1500])
    url = _extract_lora_url(result)
    if url:
        print(f"\n[fal] LoRA URL: {url}")
        print("  백엔드 등록(추론):")
        print(f'    PETFIT_LOOK_MODELS=\'{{"{args.look}": "{url}"}}\'')
        print(f'    PETFIT_LOOK_TRIGGERS=\'{{"{args.look}": "{instruction}"}}\'')
    else:
        print("\n[fal] LoRA URL 을 자동 추출 못함 — 위 결과 JSON 에서 .safetensors url 확인.")


if __name__ == "__main__":
    main()
