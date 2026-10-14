# Contexto compartido para todos los subagentes

> **Organización del equipo, reglas comunes, matriz de archivos y formato de informe: `docs/EQUIPO.md`.** Este archivo contiene las convenciones técnicas.

Lee, en este orden: este archivo, `docs/ARQUITECTURA.md` y `REQUERIMIENTOS.md` (secciones 1-3 y RF1-RF11). **Si `REQUERIMIENTOS.md` y `ARQUITECTURA.md` se contradicen en stack o estructura, manda `ARQUITECTURA.md`** (el proyecto es Godot + Firebase, no React).

## Decisiones vigentes

| # | Decisión | Valor |
|---|---|---|
| 1 | Stack | Godot 4.x + GDScript tipado; GUT para tests |
| 2 | Modos | Local (hot-seat + bots) y multijugador en línea por salas |
| 3 | Backend | Firebase Spark: Auth anónima + Realtime Database + Hosting |
| 4 | Autoridad en línea | Celular anfitrión |
| 5 | Plataformas | Android y Web |
| 6 | Too Much Mana | Límite de pociones configurable, 10 por defecto, desactivable |
| 7 | Curse of Rules | Texto libre + botón "Rompió la regla" (−1💧) |
| 8 | Ventana de reacción | Local: botón "Pasar" (temporizador opcional). En línea: temporizador obligatorio, 15 s por defecto |
| 9 | Idioma de la UI | Español (los nombres de carta quedan en inglés) |

## Reglas de trabajo

1. **Cada agente toca solo los archivos de su tarea.** El archivo compartido es `src/engine/types.gd`. Si necesitas cambiarlo, NO lo edites: escribe la petición en `docs/CAMBIOS-TIPOS.md` (qué, por qué, quién lo necesita) y continúa con un workaround local. El orquestador aplica los cambios.
2. `src/engine/effects/registry.gd`: solo añade **una línea por carta** tuya. No reordenes ni toques otras líneas.
3. El motor (`src/engine/`) es **puro**: sin nodos, escenas, señales de red ni `randi()`. Estado = `Dictionary` serializable a JSON. Azar solo con `rng.gd`.
4. GDScript con tipado estático (`var x: int`, `-> Dictionary`). Activa los warnings de tipado del proyecto y no dejes warnings nuevos.
5. Tests GUT para todo código nuevo. Antes de terminar ejecuta:
   `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
   (si el binario se llama distinto, mira `docs/VERSIONES.md`). No declares terminado con tests en rojo. Si `godot` no está instalado, para y repórtalo: es una tarea manual del usuario.
6. No inventes reglas. Consulta el manual con `pdftotext -layout` o `REQUERIMIENTOS.md`. Si sigue ambiguo, elige la lectura más literal, regístrala en `docs/AMBIGUEDADES.md` (carta/regla, opciones, elección) y sigue.
7. **Copyright:** el arte y los textos son © SUPERHOTEX, uso personal. `assets/cards`, `assets/bg`, `assets/cardback.webp` y los PDFs van en `.gitignore`. Nunca subas assets a repos públicos.
8. **Nada de acciones externas sin el orquestador:** no ejecutes `firebase deploy`, no publiques, no uses `sudo`, no escribas en el proyecto Firebase real. Para pruebas de red usa el **Firebase Emulator Suite** local.
9. Secretos/config: la config web de Firebase vive en `addons/godot-firebase/.env` (o donde indique `ARQUITECTURA.md`), fuera de git. No la imprimas en los informes.
10. Informe final (máx. 15 líneas): archivos creados/modificados, comando de tests y resultado, ambigüedades registradas, peticiones a `types.gd`, bloqueos y tareas manuales que necesitas del usuario.

## Acuerdos fijados en la oleada 0 (obligatorios)

- **Godot:** usa siempre la ruta absoluta `/home/brayan/.local/bin/godot` (los shells no interactivos no cargan `~/.zshrc`). Comando de tests:
  `/home/brayan/.local/bin/godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- **Ejecuta los tests SIEMPRE con `bash tools/test.sh`** (acepta args extra de GUT, p. ej. `-gselect=test_fire`), nunca llamando a Godot directamente. Comparte un candado con `check_warnings.sh`, así varios agentes en paralelo no se pisan con el `override.cfg` temporal.
- **Warnings:** antes de terminar ejecuta también `bash tools/check_warnings.sh` y debe decir `OK`.
- **API del motor (de T4):** `Game.new_game(players, cfg, seed)` (el catálogo sale de `CardCatalog`), `Game.reduce`, `Game.legal_actions`, `Game.resolve_spell`. Para los efectos: `Damage.apply/resolve`, `lose_hp`, `heal`, `gain_mana`, `lose_mana`, `forced_discard`, `card_cost`, `exchange_cost`, `potion_amount`, `hand_limit` y `eliminate`. Hooks: `Types.HOOK_*`, incluidos `HOOK_PROMPT`, `HOOK_LEGAL_ACTIONS` y `HOOK_PAY_WILDCARD`. Lee la cabecera de `src/engine/game.gd` antes de empezar.
- **Catálogo real:** `data/cards.json` ya está completo (61 diseños, 165 cartas, 154 jugables). Úsalo en los tests de efectos; las fixtures de `tests/fixtures/` siguen sirviendo para los tests del núcleo.
- **Ids de carta:** son las constantes `CARD_*` de `src/engine/types.gd`. No inventes otros slugs.
- **Si tu definición de agente contradice a `types.gd` o a `docs/CONTRATO-TIPOS.md`, mandan estos dos.** Por ejemplo, no existe `REACTION_TIMEOUT`: al vencer el plazo, la sesión envía `PASS_REACTION` o `DECLINE` en nombre del jugador, usando `deadline_ms` del estado.
- **Modificadores:** se registran en `src/engine/modifiers.gd` (etapas cost, outgoing, incoming, prevent, redirect, after_damage, potion, hand_limit y exchange_cost).
- **Datos de Firebase o JSON:** pásalos siempre por `Types.normalize_state` / `normalize_value`.
- **Vistas:** usa `Types.public_view`, `private_view`, `compose_view` y `view_for`.

## Rutas de recursos

- Assets origen: `~/Downloads/Not Enough Mana Print & Play Edition/`
- Cartas: `Cards/P&P cards - singles ISO.pdf` (165 págs). Reverso: `Cards/P&P cardbacks - singles ISO.pdf`.
- Manual: `Manual/P&P Manual - self-print assorted with instructions.pdf`.
- Para **ver** una carta: renderiza la página a PNG en el scratchpad (`pdftoppm -f N -l N -r 110 -png`) y ábrela con la herramienta Read.
- Herramientas disponibles: `pdftoppm`, `pdftotext`, Python 3 con Pillow (WebP), Node/npm.
