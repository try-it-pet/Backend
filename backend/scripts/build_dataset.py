#!/usr/bin/env python
"""Kontext LoRA 학습셋 빌더 — 평범한 펫 사진 → 겨울 감성 'after' 자동 생성 → 쌍 zip.

각 소스 이미지(before)를 gpt-image-2 로 감성 룩 버전(after)으로 만들어
Flux Kontext 트레이너 형식(`0001_start.ext` / `0001_end.png` / `0001.txt`)으로 묶는다.
정체성·포즈는 유지하고 옷/악세서리는 추가하지 않는다(스타일 변환만 학습).

사용:
  cd backend
  python scripts/build_dataset.py --src "C:/Users/.../학습소스" --look winter --out ./winter.zip
  # 결과 winter.zip → scripts/train_lora.py 의 --images 로 사용.

주의: 소스 1장당 gpt-image-2 1회 생성(소액 과금). PETFIT_OPENAI_API_KEY 필요.
"""

from __future__ import annotations

import argparse
import base64
import io
import os
import sys
import tempfile
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))  # backend/ 를 path 에
from app.config import settings  # noqa: E402
from app.providers.looks import LOOK_PROMPTS  # noqa: E402

_EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def _edit_prompt(look: str, instruction: str) -> str:
    style = LOOK_PROMPTS.get(look, look)
    return (
        "Keep this exact pet's identity, fur, face and pose unchanged; do NOT add any clothing, "
        f"hats or accessories. Only restyle the photo. {style}. ({instruction})"
    )


def _make_after(path: Path, prompt: str, size: str) -> bytes:
    from openai import OpenAI

    client = OpenAI(api_key=settings.openai_api_key)
    with open(path, "rb") as f:
        img = io.BytesIO(f.read())
    img.name = "src.png"
    resp = client.images.edit(model=settings.openai_model, image=img, prompt=prompt, size=size)
    return base64.b64decode(resp.data[0].b64_json)


def main() -> None:
    ap = argparse.ArgumentParser(description="Kontext LoRA 학습셋 빌더")
    ap.add_argument("--src", required=True, help="평범한 펫 사진 폴더")
    ap.add_argument("--look", default="winter", help="감성 룩 키 (LOOK_PROMPTS)")
    ap.add_argument("--out", default="./dataset.zip", help="결과 zip 경로")
    ap.add_argument("--instruction", default=None, help="지시문(기본: apply Pawdy <look> style)")
    ap.add_argument("--size", default=None, help="생성 크기(기본: settings.openai_size)")
    ap.add_argument("--workers", type=int, default=4, help="동시 생성 수")
    args = ap.parse_args()

    if not settings.openai_api_key:
        sys.exit("PETFIT_OPENAI_API_KEY 가 필요합니다(backend/.env).")
    src = Path(args.src)
    if not src.is_dir():
        sys.exit(f"소스 폴더를 찾을 수 없습니다: {src}")

    instruction = args.instruction or f"apply Pawdy {args.look} style"
    size = args.size or settings.openai_size
    prompt = _edit_prompt(args.look, instruction)

    imgs = sorted(p for p in src.iterdir() if p.suffix.lower() in _EXTS)
    if not imgs:
        sys.exit("소스 이미지가 없습니다.")
    print(f"[build] {len(imgs)}장 → 겨울 감성 after 생성(gpt-image-2, workers={args.workers})")

    tmp = Path(tempfile.mkdtemp(prefix="pawdy_ds_"))
    ok = 0

    def _one(i: int, path: Path):
        from PIL import Image

        after = _make_after(path, prompt, size)
        idx = f"{i:04d}"
        # Kontext 트레이너는 start/end 를 같은 확장자·해상도로 짝지어야 하고,
        # 큰 원본은 학습 시 GPU OOM 을 유발 → start 를 정사각 1024x1024 로 통일(png).
        im = Image.open(path).convert("RGB")
        w, h = im.size
        s = min(w, h)
        im = im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
        im.resize((1024, 1024), Image.LANCZOS).save(tmp / f"{idx}_start.png")
        (tmp / f"{idx}_end.png").write_bytes(after)
        (tmp / f"{idx}.txt").write_text(instruction, encoding="utf-8")
        return idx

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(_one, i, p): p for i, p in enumerate(imgs, 1)}
        for fut in as_completed(futs):
            p = futs[fut]
            try:
                idx = fut.result()
                ok += 1
                print(f"  ✓ {p.name} → {idx}_start/{idx}_end")
            except Exception as exc:  # noqa: BLE001
                print(f"  ✗ {p.name}: {exc}")

    if ok == 0:
        sys.exit("생성된 쌍이 없습니다.")

    out = Path(args.out)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(tmp.iterdir()):
            z.write(f, f.name)
    print(f"\n[build] 완료: {ok}쌍 → {out.resolve()}")
    print("  다음: python scripts/train_lora.py --look "
          f"{args.look} --images {out} --destination <owner>/pawdy-{args.look} ...")


if __name__ == "__main__":
    main()
