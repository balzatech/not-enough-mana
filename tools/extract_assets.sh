#!/usr/bin/env bash
# Extrae y convierte los assets del P&P a WebP. Idempotente.
set -euo pipefail

SRC="${SRC:-$HOME/Downloads/Not Enough Mana Print & Play Edition}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/home/brayan/.local/bin/godot}"
OUT="$ROOT/assets"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -d "$SRC" ] || { echo "SRC no existe: $SRC" >&2; exit 1; }
mkdir -p "$OUT/cards" "$OUT/bg"

echo "== Cartas =="
mkdir -p "$TMP/cards"
pdftoppm -r 200 -png "$SRC/Cards/P&P cards - singles ISO.pdf" "$TMP/cards/c"
n=0
for f in $(ls "$TMP/cards"/*.png | sort); do
  n=$((n+1))
  id=$(printf '%03d' "$n")
  python3 "$ROOT/tools/to_webp.py" "$f" "$OUT/cards/$id.webp" --width 500 --quality 80 --max-kb 150 >/dev/null
done
echo "$n cartas"

echo "== Reverso =="
pdftoppm -r 200 -png -f 1 -l 1 "$SRC/Cards/P&P cardbacks - singles ISO.pdf" "$TMP/back"
python3 "$ROOT/tools/to_webp.py" "$(ls "$TMP"/back*.png | head -1)" "$OUT/cardback.webp" --width 500 --quality 80 --max-kb 150

echo "== Fondos =="
for i in 1 2 3 4; do
  python3 "$ROOT/tools/to_webp.py" "$SRC/Extras/NEM Wallpaper 0$i.png" "$OUT/bg/wallpaper-0$i.webp" --max-side 1920 --quality 80
done
python3 "$ROOT/tools/to_webp.py" "$SRC/Extras/NEM Avatar 01.png" "$OUT/bg/avatar-01.webp" --max-side 1920 --quality 80
python3 "$ROOT/tools/to_webp.py" "$SRC/NEM P&P Cover.jpg" "$OUT/bg/cover.webp" --max-side 1920 --quality 80

echo "== Manifest =="
python3 -I - "$OUT" <<'PY'
import json, sys, glob
from PIL import Image
out = sys.argv[1]
files = sorted(glob.glob(out + "/cards/[0-9][0-9][0-9].webp"))
w, h = Image.open(files[0]).size
json.dump({"count": len(files), "width": w, "height": h}, open(out + "/cards/manifest.json", "w"))
print(len(files), w, h)
PY

if [ -x "$GODOT" ] || command -v godot >/dev/null 2>&1; then
  G="$GODOT"; [ -x "$G" ] || G="$(command -v godot)"
  echo "== Import Godot =="
  # 1.ª pasada: genera los .import
  "$G" --headless --path "$ROOT" --import >"$TMP/imp1.log" 2>&1 || true
  # Compresion Lossless (mode 0) en lugar de VRAM
  for f in "$OUT"/cards/*.import "$OUT"/bg/*.import "$OUT"/cardback.webp.import; do
    [ -f "$f" ] && sed -i 's/^compress\/mode=.*/compress\/mode=0/; s/^mipmaps\/generate=.*/mipmaps\/generate=false/' "$f"
  done
  rm -rf "$ROOT/.godot/imported"/*.webp-* 2>/dev/null || true
  "$G" --headless --path "$ROOT" --import >"$TMP/imp2.log" 2>&1 || true
  if grep -E "^(ERROR|SCRIPT ERROR)" "$TMP/imp2.log" | grep -i -E "webp|assets/" ; then
    echo "Errores de importacion en assets" >&2; exit 1
  fi
  echo "Import OK"
else
  echo "godot no encontrado; omito import"
fi

echo "== Peso =="
du -sh "$OUT"
du -sh "$OUT/cards" "$OUT/bg"
big=$(find "$OUT/cards" -name '*.webp' -size +150k | wc -l)
echo "Cartas > 150 KB: $big"
[ "$big" -eq 0 ]
