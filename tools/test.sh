#!/usr/bin/env bash
# Ejecuta la suite GUT completa (o los args extra de GUT que pases).
# Usa el mismo candado que tools/check_warnings.sh para que nunca corran a la vez
# (check_warnings crea un override.cfg temporal que afectaría a los tests).
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$HOME/.local/bin/godot}"
exec 9>".godot/nem-godot.lock"
flock 9
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit "$@"
