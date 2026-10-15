# Inventario de archivos (2026-10-14)

> **Estado (aplicado el 2026-10-14, sin commitear):** borrados `data/parts/` (3), 3 `.gitkeep` sobrantes, 3 escenas sin uso, la función `UiNav.make_fake_session`, la rama de demostración de `table.gd` (`demo_when_empty`) y los datos crudos de rendimiento; movidos `FakeState`/`FakeSession` a `tests/fixtures/`, **toda** la carpeta de benchmarks a `tools/perf/` (no solo los 4 puntuales: heredan de `perf_final.gd`) y 10 informes cerrados a `docs/historico/v0.2/` (con `LEEME.md`); `resumenes-cartas.md` y `validacion-resumenes.md` dejan de versionarse; `override.cfg` añadido a `.gitignore`; `check_warnings.sh` revisa también `tools/`. Verificado: importación sin errores, `check_warnings` OK, 717/717 tests. Pendiente de decisión: las capturas de pantalla en disco.

Pregunta: hay casi 2000 archivos en la carpeta del proyecto; ¿son todos útiles?

## De dónde salen los números

| Grupo | Archivos | ¿Versionado? | Qué es |
|---|---|---|---|
| `.godot/` | 680 | No (ignorado) | Caché de importación de Godot. Se regenera sola; normal en cualquier proyecto Godot |
| `assets/cards` + `assets/bg` + reverso | 345 | No (copyright) | Imágenes de cartas y fondos con sus `.import`. Necesarias para jugar; se regeneran con `tools/extract_assets.sh` desde los PDF |
| `docs/revision/capturas` + `salidas` | 235 (71 MB) | No | Capturas de pantalla de las revisiones. Se regeneran con los scripts de captura |
| `addons/gut` | 259 | Sí | La librería de tests GUT, incluida tal cual (práctica estándar en Godot) |
| `.uid` de nuestros scripts | 159 | Sí | Identificadores que Godot 4.4+ genera, uno por script; deben versionarse |
| `.import` de nuestros recursos | 18 | Sí | Configuración de importación de iconos y fuente |
| **Archivos escritos por el proyecto** | **~280** | Sí | Código, tests, datos, documentos, herramientas y agentes |

Conclusión: de los ~1976 archivos en disco, unos **1260 son caché o recursos regenerables** y **~280 son el proyecto de verdad**. El grueso está justificado; abajo, lo que sobra.

## Se puede eliminar sin pérdida (verificado)

| Archivo(s) | Por qué |
|---|---|
| `data/parts/p001-073.json`, `p074-131.json`, `p132-165.json` | Tramos del catálogo que se unieron en `data/cards.json`; contenido **idéntico** (comprobado) y ningún código los usa |
| `assets/.gitkeep`, `tests/ai/.gitkeep`, `tests/integration/.gitkeep` | Marcadores de carpeta vacía en carpetas que ya tienen archivos |
| `src/ui/components/card_view.tscn`, `player_panel.tscn`, `src/ui/screens/reaction_prompt.tscn` | El juego crea esos componentes con `.new()`; las escenas solo las carga un test de instanciación (habría que quitarlas también de `tests/ui/test_ui_scenes.gd`) |
| `UiNav.make_fake_session` (función) | Definida y sin ningún uso |
| `tests/perf/*.txt` (5 archivos, ~515 KB) | Datos crudos de mediciones puntuales; las conclusiones ya están en `docs/rendimiento/v02-base.md` y `v02-final.md` |

## Mover (sirven, pero están en el sitio equivocado)

| Archivo(s) | A dónde | Por qué |
|---|---|---|
| `src/ui/fixtures/fake_state.gd`, `fake_session.gd` | `tests/fixtures/` | Son de pruebas; hoy viajarían dentro de una exportación del juego. Requiere quitar `demo_when_empty` de `table.gd` |
| Informes de proceso cerrados de la v0.2: `docs/qa/puerta-o1.md`, `puerta-o2.md`, `puerta-o3.md`, `confirmacion-p2-p7.md`, `metricas-base-mvp-sesgada.md`, `metricas-base-v02-bots-previos.md`, `docs/revision/ENCARGO-DIRECTOR.md`, `evaluacion-o1.md`, `docs/INFORME-CATALOGO.md`, `docs/rendimiento/v02-base.md` | `docs/historico/v0.2/` | Son el registro de cómo se llegó aquí (útil como auditoría), pero ya no son documentación viva y confunden al buscar la versión vigente |
| Scripts de investigación de rendimiento puntuales: `tests/perf/perf_ablate.gd`, `perf_layer.gd`, `perf_glyph.gd`, `perf_objects.gd` | `tools/perf/` | No son tests; se usaron una vez para diagnosticar |

## Simplificar (útiles, pero duplicados)

- **10 scripts de captura** (771 líneas: `tests/ui/capture*.gd`, `tests/integration/capture_local.gd`): uno por tarea, con la misma preparación repetida. Se pueden unificar en uno con modos.
- **Tests de las puertas de QA** (`tests/qa/test_puerta_*.gd`, 2141 líneas): sirven como regresión, pero `test_puerta_o3.gd` **comprueba el texto de documentos** (el guion M12 y las cifras de `opciones-bloqueo-pociones.md`). Eso ya se rompió una vez al corregir el guion. Los tests deberían comprobar código, no documentos.

## Decisiones que son tuyas

1. **`docs/narrativa/resumenes-cartas.md` está versionado** y contiene los mismos resúmenes en español que sacamos de git por copyright (`data/card_summaries_es.json`, M19). Lo mismo, en menor medida, `docs/diseno/validacion-resumenes.md`, que trae textos propuestos. Opciones: (a) ignorarlos también y sacarlos del historial del próximo commit (el commit `104a7c9` ya los contiene; solo importa si algún día se publica el repositorio); (b) mantenerlos, asumiendo que el repositorio es solo local y privado.
2. **Marcadores de futuro** (`firebase/.gitkeep`, `tests/net/.gitkeep`, los 5 *stubs* de 3 líneas de `src/net/` y `src/session/online_session.gd`, y la pantalla `lobby.gd` oculta): guardarlos para el modo en línea (v0.4 o después) o quitarlos y recrearlos entonces. Tres de los *stubs* (`FirebaseClient`, `RoomService`, `StateView`) no los referencia nada.
3. **Capturas en disco** (71 MB, no versionadas): conservar todas, solo las últimas (v2-33 en adelante) o ninguna (se regeneran).
4. **Agentes "en reserva"** (`level-designer`, `narrative-designer`, `audio-agent`…): los pediste explícitamente; se mantienen salvo que decidas lo contrario.

## Lo que está bien y se mantiene
`src/`, `tests/` (salvo lo indicado), `tools/` (simulador, extracción de assets, tests y warnings), `data/cards.json`, `assets/ui` y `assets/fonts` (recursos propios y fuente con licencia), `addons/gut`, `.claude/agents` y la documentación viva (`ARQUITECTURA`, `CONTRATO-TIPOS`, `EQUIPO`, `VISION`, `DECISIONES`, `ESCALADOS`, `AMBIGUEDADES`, `BACKLOG`, `TAREAS`, `TECNICO/*`, `diseno/*`, `arte/*`, `qa/bugs.md`, `qa/informe-v02.md`, `qa/metricas-final.md`, `qa/guion-m12.md`, `rendimiento/v02-final.md`).
