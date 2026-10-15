#!/usr/bin/env bash
# Ejecuta la suite GUT completa (o los args extra de GUT que pases).
# Usa el mismo candado que tools/check_warnings.sh para que nunca corran a la vez
# (ambos comparten .godot). Espera como máximo NEM_LOCK_TIMEOUT segundos (60 por defecto).
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/.local/bin/godot}"
mkdir -p .godot
exec 9>".godot/nem-godot.lock"
if ! flock -w "${NEM_LOCK_TIMEOUT:-60}" 9; then
  echo "ERROR: no se pudo obtener .godot/nem-godot.lock en ${NEM_LOCK_TIMEOUT:-60}s (¿otro test.sh/check_warnings.sh colgado?)" >&2
  exit 75
fi
# Clon nuevo: sin caché de clases ni importación GUT no arranca. Se importa una sola vez.
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  echo "Primera ejecución: importando el proyecto..." >&2
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi
# Salida de GUT a un archivo temporal (se muestra tal cual) para contar los nodos huérfanos.
OUT="$(mktemp)"
trap 'rm -f "$OUT" "${OUT_CANARY:-}"' EXIT
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }
# Cuenta huérfanos: línea "N Orphans" por test (suma) y la línea "Orphans N" de los totales (el mayor).
count_orphans() {
  strip_ansi < "$1" | awk '
    /^[[:space:]]+[0-9]+ Orphans[[:space:]]*$/ { per += $1; tests++ }
    /^Orphans[[:space:]]+[0-9]+/ { tot = $2 }
    END { n = (per > tot) ? per : tot; printf "%d %d\n", n, tests }'
}
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit "$@" 2>&1 | tee "$OUT"
code=${PIPESTATUS[0]}
read -r N T < <(count_orphans "$OUT")
echo "HUERFANOS: $N en $T tests"
# Que el 0 no sea un silenciamiento: ni la configuración ni los argumentos ocultan huérfanos,
# y un canario con un nodo sin liberar tiene que contarse.
if grep -qi "hide_orphans" .gutconfig.json || printf '%s\n' "$@" | grep -qi "hide_orphans"; then
  echo "ERROR: la configuración de GUT oculta los huérfanos (hide_orphans)" >&2
  exit 1
fi
if [ "$N" -eq 0 ] && [ "${NEM_SKIP_CANARY:-0}" != "1" ] && [ "$#" -eq 0 ]; then
  OUT_CANARY="$(mktemp)"
  "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/base -gprefix=orphan_canary -gexit >"$OUT_CANARY" 2>&1
  read -r NC _ < <(count_orphans "$OUT_CANARY")
  if [ "$NC" -lt 1 ]; then
    echo "ERROR: el canario de huérfanos no se contó: el 0 de arriba no es fiable (¿GUT ignora los huérfanos?)" >&2
    exit 1
  fi
fi
if [ "$N" -gt 0 ]; then
  echo "ERROR: hay $N nodos huérfanos en los tests (cada test debe liberar lo que crea)" >&2
  [ "$code" -eq 0 ] && code=1
fi
exit "$code"
