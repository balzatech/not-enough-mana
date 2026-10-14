#!/usr/bin/env bash
# Línea base V2-20: 3 y 6 jugadores x 1080x1920 y 720x1280 x (real, stress) x 3 repeticiones.
# Uso: DISPLAY=:0 bash tests/perf/run_v02_base.sh > /tmp/perf_v02.txt ; python3 -I tests/perf/aggregate.py /tmp/perf_v02.txt
# Tarda ~12 min. No ejecutar nada pesado a la vez. Necesita GPU/pantalla (no headless).
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-$HOME/.local/bin/godot}"
REPS="${REPS:-3}"
for r in $(seq 1 "$REPS"); do
  for np in 3 6; do
    for res in "1080 1920" "720 1280"; do
      for mode in "real 30" "stress 15"; do
        # shellcheck disable=SC2086
        "$GODOT" --path . -s tests/perf/perf_table.gd -- $np $res $mode 11 2>&1 | grep '^PERF '
      done
    done
  done
done
