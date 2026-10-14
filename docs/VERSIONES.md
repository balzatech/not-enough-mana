# Versiones fijadas

| Herramienta | Versión | Notas |
|---|---|---|
| Godot | **4.7.2.stable.official.ed1daf0bf** (Standard, Linux x86_64) | Binario: `godot` en el PATH = `~/.local/bin/godot` → `~/apps/godot/Godot_v4.7.2-stable_linux.x86_64`. Si el shell no lo encuentra, usa la ruta absoluta `/home/brayan/.local/bin/godot`. |
| GUT | **9.7.1** (tag `v9.7.1` de `bitwes/Gut`, 2026-07-10) | Rama 9.7.x = compatible con Godot 4.7 (9.7.0 adapta los dobles al tipado de retorno de 4.7). Instalado en `addons/gut/` y habilitado en `project.godot`. |
| Renderer | GL Compatibility | Necesario para Web y Android de gama baja. |

## Comandos

```bash
# Importar (primera vez o tras añadir assets)
godot --headless --path . --import

# Tests (todos)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Warnings de tipado (Godot headless no los imprime; este script los convierte en errores)
tools/check_warnings.sh            # src/ y tests/
tools/check_warnings.sh src/engine # una carpeta
```

## Warnings de GDScript activos (`project.godot`, sección `[debug]`)

- `untyped_declaration`, `unsafe_property_access`, `unsafe_method_access`: **warn**. Hay que declarar tipos
  y asignar a una variable tipada antes de llamar métodos (`var hand: Array = p["hand"]`).
- `unsafe_cast` y `unsafe_call_argument`: **desactivados** a propósito. El estado es un `Dictionary` JSON y
  cada lectura devuelve `Variant`; con esos dos warnings activos, `(d["x"] as Array)` o `int(d["x"])`
  generan decenas de avisos inevitables por archivo.
- `exclude_addons=true`: no se reportan warnings de `addons/` (GUT, Firebase).
