#!/usr/bin/env python3
"""Quita el rectangulo negro de fondo de los SVG de game-icons.net.

Uso: python3 -I tools/strip_icon_bg.py <archivo.svg|carpeta> [...]
Idempotente, solo biblioteca estandar. Trata los SVG como texto: nunca los ejecuta.
Rechaza (sin tocar) archivos con <script>, atributos on*= o referencias externas.
La forma queda en blanco (fill="#fff") para teñirla con self_modulate.
"""
import re
import sys
from pathlib import Path

# Fondo: <path d="M0 0h512v512H0z"/> (con o sin espacios, o 'M0,0 H512 V512 H0 Z').
BG = re.compile(
    r'<path\s+(?:fill="#0{3,6}"\s+)?d="M\s*0[ ,]\s*0\s*[hH]\s*512\s*[vV]\s*512\s*[hH]\s*0\s*[zZ]"\s*(?:fill="#0{3,6}"\s*)?/>',
    re.I)
UNSAFE = re.compile(r'<script|\son\w+\s*=|xlink:href|href\s*=\s*["\'](?!#)|<image|<foreignObject|https?://(?!www\.w3\.org/)', re.I)


def process(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if UNSAFE.search(text):
        return "RECHAZADO (contenido no seguro)"
    new = BG.sub("", text)
    if new == text:
        return "sin cambios"
    path.write_text(new, encoding="utf-8")
    return "fondo quitado"


def main(args):
    if not args:
        print(__doc__)
        return 2
    files = []
    for a in args:
        p = Path(a)
        files += sorted(p.glob("*.svg")) if p.is_dir() else [p]
    bad = 0
    for f in files:
        r = process(f)
        bad += r.startswith("RECHAZADO")
        print(f"{f.name}: {r}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
