#!/usr/bin/env bash
# Comprueba que los scripts GDScript no tienen warnings.
# En modo headless Godot no imprime los warnings, así que este script crea un
# override.cfg que convierte en ERROR cada warning activo del proyecto
# (más los de variables/parámetros sin usar) y ejecuta --check-only por archivo.
# El override.cfg NUNCA se escribe en la raíz del repo: vive en un directorio temporal
# (mktemp) que contiene enlaces simbólicos a todo el proyecto, y Godot se ejecuta con
# --path sobre ese directorio. Si el script muere con kill -9 la raíz queda intacta.
# Uso: tools/check_warnings.sh [ruta ...]   (por defecto: src, tests y tools)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
# Candado compartido con tools/test.sh (ambos usan .godot). Espera acotada.
mkdir -p .godot
exec 9>".godot/nem-godot.lock"
if ! flock -w "${NEM_LOCK_TIMEOUT:-60}" 9; then
  echo "ERROR: no se pudo obtener .godot/nem-godot.lock en ${NEM_LOCK_TIMEOUT:-60}s (¿otro test.sh/check_warnings.sh colgado?)" >&2
  exit 75
fi
ROOT="$PWD"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nem-warnings.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
for e in "$ROOT"/* "$ROOT"/.godot; do
  [ "$(basename "$e")" = "override.cfg" ] && continue
  ln -s "$e" "$TMP/$(basename "$e")"
done
cat > "$TMP/override.cfg" <<'CFG'
[debug]
gdscript/warnings/untyped_declaration=2
gdscript/warnings/unsafe_property_access=2
gdscript/warnings/unsafe_method_access=2
gdscript/warnings/inference_on_variant=2
gdscript/warnings/unused_variable=2
gdscript/warnings/unused_local_constant=2
gdscript/warnings/unused_parameter=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/shadowed_variable_base_class=2
gdscript/warnings/shadowed_global_identifier=2
gdscript/warnings/integer_division=2
gdscript/warnings/narrowing_conversion=2
gdscript/warnings/incompatible_ternary=2
gdscript/warnings/static_called_on_instance=2
gdscript/warnings/unreachable_code=2
gdscript/warnings/standalone_expression=2
CFG
dirs=("$@"); [ ${#dirs[@]} -eq 0 ] && dirs=(src tests tools)
fail=0
while IFS= read -r f; do
  out=$("$GODOT" --headless --path "$TMP" --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|ERROR:" -A1)
  if [ -n "$out" ]; then echo "== $f"; echo "$out"; fail=1; fi
done < <(find "${dirs[@]}" -name '*.gd' | sort)
[ $fail -eq 0 ] && echo "OK: sin warnings"
exit $fail
