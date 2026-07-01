"""인생네컷(2x2) 합성 — 4장의 컷을 포토부스풍 프레임에 배치해 한 장 PNG 로 만든다.

스토리에 꽉 차게 정사각형 2x2. 각 컷은 정사각 센터크롭 + 살짝 둥근 모서리,
하단에 'Pawdy' 워드마크. 실패/mock 컷은 플레이스홀더 셀로 대체한다.
"""

from __future__ import annotations

import io

from PIL import Image, ImageDraw, ImageFont

# Pawdy 톤 (프론트 T.paper/accent 계열)
_BG = (247, 242, 236)      # 따뜻한 크림
_CELL_BG = (233, 227, 219)
_ACCENT = (232, 103, 74)   # E8674A
_MUTED = (168, 159, 149)

_CELL = 512      # 셀 한 변
_GUT = 22        # 셀 간격
_MARGIN = 30     # 외곽 여백
_FOOTER = 74     # 하단 워드마크 영역
_RADIUS = 26


def _load_square(data: bytes) -> Image.Image:
    """바이트 → 정사각 센터크롭된 RGB 이미지(_CELL 크기)."""
    im = Image.open(io.BytesIO(data)).convert("RGB")
    w, h = im.size
    side = min(w, h)
    im = im.crop(((w - side) // 2, (h - side) // 2, (w - side) // 2 + side, (h - side) // 2 + side))
    return im.resize((_CELL, _CELL), Image.LANCZOS)


def _placeholder(label: str) -> Image.Image:
    """생성 실패/mock 컷용 플레이스홀더 셀."""
    im = Image.new("RGB", (_CELL, _CELL), _CELL_BG)
    d = ImageDraw.Draw(im)
    d.text((_CELL // 2, _CELL // 2), label, fill=_MUTED, anchor="mm", font=_font(34))
    return im


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("malgun.ttf", "arial.ttf", "DejaVuSans.ttf"):  # 한글/기본 폴백
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _round(im: Image.Image, radius: int) -> Image.Image:
    """정사각 이미지에 둥근 모서리 알파 마스크 적용."""
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0], im.size[1]], radius=radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def compose_2x2(cells: list[bytes | None], labels: list[str]) -> bytes:
    """4개 컷(바이트 또는 None) → 2x2 인생네컷 PNG 바이트."""
    w = _MARGIN * 2 + _CELL * 2 + _GUT
    h = _MARGIN * 2 + _CELL * 2 + _GUT + _FOOTER
    canvas = Image.new("RGB", (w, h), _BG)

    for i in range(4):
        col, row = i % 2, i // 2
        x = _MARGIN + col * (_CELL + _GUT)
        y = _MARGIN + row * (_CELL + _GUT)
        try:
            cell = _load_square(cells[i]) if cells[i] else _placeholder(labels[i])
        except Exception:  # noqa: BLE001 (깨진 이미지 → 플레이스홀더)
            cell = _placeholder(labels[i])
        canvas.paste(_round(cell, _RADIUS), (x, y), _round(cell, _RADIUS))

    d = ImageDraw.Draw(canvas)
    footer_y = _MARGIN + _CELL * 2 + _GUT + _FOOTER // 2
    d.text((w // 2, footer_y), "Pawdy", fill=_ACCENT, anchor="mm", font=_font(38))

    buf = io.BytesIO()
    canvas.save(buf, format="PNG")
    return buf.getvalue()
