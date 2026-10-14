#!/usr/bin/env python3
"""Convierte imagenes a WebP. Uso:
  to_webp.py IN OUT [--width N] [--max-side N] [--quality Q] [--max-kb K]
Si se pasa --max-kb, baja la calidad hasta cumplir el limite."""
import argparse
import os
import sys
from PIL import Image


def convert(src: str, dst: str, width: int = 0, max_side: int = 0,
            quality: int = 80, max_kb: int = 0) -> tuple[int, int, int, int]:
    img = Image.open(src)
    img = img.convert("RGBA" if img.mode in ("RGBA", "LA", "P") and "transparency" in img.info or img.mode == "RGBA" else "RGB")
    w, h = img.size
    if width and w != width:
        img = img.resize((width, round(h * width / w)), Image.LANCZOS)
    elif max_side and max(w, h) > max_side:
        s = max_side / max(w, h)
        img = img.resize((round(w * s), round(h * s)), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    q = quality
    while True:
        img.save(dst, "WEBP", quality=q, method=6)
        size = os.path.getsize(dst)
        if not max_kb or size <= max_kb * 1024 or q <= 30:
            break
        q -= 5
    return img.size[0], img.size[1], q, size


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--width", type=int, default=0)
    p.add_argument("--max-side", type=int, default=0)
    p.add_argument("--quality", type=int, default=80)
    p.add_argument("--max-kb", type=int, default=0)
    a = p.parse_args()
    w, h, q, size = convert(a.src, a.dst, a.width, a.max_side, a.quality, a.max_kb)
    print(f"{a.dst} {w}x{h} q={q} {size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
