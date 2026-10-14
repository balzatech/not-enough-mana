#!/usr/bin/env bash
# Medicion final V2-34: 3 y 6 jugadores x 1080x1920 y 720x1280 x (real 30 s, stress 15 s) + ui + leak, x REPS repeticiones.
# Uso: DISPLAY=:0 bash tests/perf/run_v02_final.sh > /tmp/perf_v02_final.txt ; python3 -I tests/perf/aggregate_final.py /tmp/perf_v02_final.txt
# Tarda ~20 min con REPS=3. Usa el candado del proyecto: no ejecutar la suite de tests ni nada pesado a la vez. Necesita GPU/pantalla.
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-$HOME/.local/bin/godot}"
REPS="${REPS:-3}"
run() { flock .godot/nem-godot.lock "$GODOT" --path . -s tests/perf/perf_final.gd -- "$@" 2>&1 | grep '^PERF '; }
for r in $(seq 1 "$REPS"); do
  for np in 3 6; do
    for res in "1080 1920" "720 1280"; do
      # shellcheck disable=SC2086
      run $np $res real 30 11
      # shellcheck disable=SC2086
      run $np $res stress 15 11
      # shellcheck disable=SC2086
      run $np $res ui 1 11
      # shellcheck disable=SC2086
      run $np $res leak 60 11
    done
  done
done
