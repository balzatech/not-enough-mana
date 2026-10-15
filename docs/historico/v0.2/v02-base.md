# V2-20 Línea base de rendimiento de la mesa (antes de feedback animado y tema nuevo)

Fecha 2026-10-13. Sin cambios de código de producción. Máquina: Godot 4.7.2, gl_compatibility, Mesa 26.0.3, AMD Radeon Vega 10 (iGPU), Wayland :0. Vsync desactivado y `max_fps=0` para medir coste real. Render a SubViewport (1080x1920 o 720x1280 con `size_2d_override` 1080x1920, como un móvil con stretch canvas_items). Semilla 11, 3 repeticiones por configuración (procesos nuevos). Datos crudos: `tools/perf/v02-base-raw.txt` (eliminado del repositorio el 2026-10-14 por limpieza; se regenera con el comando de abajo).

## Reproducir
```
DISPLAY=:0 bash tools/perf/run_v02_base.sh > /tmp/perf_v02.txt     # ~12 min, GPU real, nada más corriendo
python3 -I tools/perf/aggregate.py /tmp/perf_v02.txt                # media, sd, min, max
# una sola configuración:
DISPLAY=:0 godot --path . -s tools/perf/perf_table.gd -- <jugadores> <ancho> <alto> <real|stress> <segundos> [semilla]
```
El script `tools/perf/perf_table.gd` no empieza por `test_` ni lo recoge GUT. Monta `LocalSession.create` + `table.tscn` (como `capture_local.gd`): p1 humano (lo juega el script con `Bot.choose_action`) y el resto bots. Modo `real` = retardo de bot por defecto (600-900 ms), 30 s; `stress` = retardo 0 (una acción de bot por fotograma), 15 s.

## Resultados (media de 3 ejecuciones; sd entre paréntesis). Ms por fotograma.
Fotograma "activo" = el que contiene un `state_changed` (una acción aplicada y la mesa redibujada). Resto = inactivo.

| Config (modo real) | p50 todos | p95 todos | activo p50 | activo p95 | activo máx | fotogramas activos |
|---|---|---|---|---|---|---|
| 3j 1080x1920 | 2,1 (0,02) | 2,9 (0,02) | 38,3 (1,4) | 54,8 (0,4) | 60,8 | 57 de ~14000 |
| 3j 720x1280 | 1,8 (0,02) | 2,6 (0,04) | 38,0 (2,5) | 52,4 (0,7) | 59,2 | 57 |
| 6j 1080x1920 | 2,3 (0,02) | 3,2 (0,00) | 42,2 (2,4) | 56,7 (2,5) | 67,6 | 45 |
| 6j 720x1280 | 2,0 (0,02) | 2,9 (0,01) | 41,5 (1,7) | 56,6 (2,1) | 64,7 | 45 |

Lectura: el 99,6 % de los fotogramas (inactivos) cuesta 2-3 ms (muy por debajo de 16 ms), pero cada acción de bot genera un fotograma de 38-68 ms (2,5-4 veces el presupuesto de 16 ms): un tirón por acción. En modo `stress` (acción por fotograma) la mesa va a 49-54 ms p50 y 93-110 ms p95, es decir ~19 fps: peor caso si el feedback animado provoca más redibujados.

| Coste por operación (ms) | 3j 1080 | 6j 1080 | Nota |
|---|---|---|---|
| `refresh()` de la mesa | 32,9 (2,3) | 28,7 (1,5) | 28-43 ms según estado (stress: 33-44). Una medición suelta inicial dio 10 ms; depende de log/avisos/mano |
| `submit_action` humano completo (reduce + vista + señales + refresh) | 25,5 (0,4) | 20,9 (0,5) | en stress 36-38 |
| Primer `bind_session`+refresh | 7,6 | 11,3 | |
| Instanciar `table.tscn` | 10,6 | 12,0 | |
| `Game.reduce` | 0,39 | 4,2 | 6 jug: acción de carta; ver aviso |
| `Game.legal_actions` | 0,013 | 0,93 | ver aviso |
| Decisión de bot (`Bot.choose_action`) | 0,04 | 1,6 | ver aviso |
| `Types.view_for` | 0,85 | 0,62 | |
| `Types.validate_state` | 1,2 | 0,96 | 1,6-1,7 en estados de stress (más log) |

Aviso: los microbenchmarks de motor se miden sobre el estado final de la partida, que cambia entre configuraciones (en 3j stress la partida ya había terminado y `reduce` devuelve error rápido: 0,003 ms; ese dato no es válido y se excluye). Úsense solo como orden de magnitud: reduce <5 ms, legal_actions <1 ms, bot <2 ms; todos muy por debajo de refresh. Para V2-34 conviene fijar un estado de partida (fixture) para estas cifras.

| Recursos | 3j | 6j |
|---|---|---|
| Nodos de la mesa (`table`) | 153 (159 stress) | 191 (209) |
| Nodos totales (`OBJECT_NODE_COUNT`) | 171 (183) | 213 (241) |
| Draw calls p50 | 85-87 | 130-134 |
| GPU (render time del viewport) p50 / p95 | 1,5 / 2,1 (1080); 0,9 / 1,3 (720) | 1,3 / 1,7 (1080); 0,9 / 1,5 (720) |
| GPU en stress p50 | 7,5 (1080), 3,6 (720) | 6,8 (1080), 3,4 (720) |
| Texturas cargadas (`load`, 172 .webp, no 165) | 172 | 172 |
| Memoria de texturas (`RENDER_TEXTURE_MEM_USED`) | +275 MB (de 4 a 279 con 720; 288 con 1080) | igual |
| `MEMORY_STATIC` | 52 MB tras cargar; 68-71 MB tras partida | igual |
| VRAM (`RENDER_VIDEO_MEM_USED`) | 290 (720) / 300 (1080) MB | igual |

## Cuellos de botella probables
1. **`TableScreen.refresh()` rehace todo en cada `state_changed`** (28-43 ms): `rebuild_rivals`, `center.rebuild`, `hand.refresh_hand` reconstruyen nodos (la mesa sube de 153 a 209 nodos con 6 jugadores). Es la causa del tirón de ~40 ms por acción; el motor (reduce+legal+bot ~ <7 ms) y la GPU (<3 ms en modo real) no lo explican. Para V2-22: un feedback animado que dispare refresh por evento o por fotograma llevaría la mesa al régimen `stress` (~19 fps). Recomendación: reutilizar nodos / actualizar en sitio, o no encadenar refresh completo con animaciones. Aún no perfilado por módulo (siguiente paso: cronometrar cada llamada de `refresh()` con `Time.get_ticks_usec()` en una copia de prueba).
2. **Memoria de texturas ~280-290 MB** con las 172 imágenes descomprimidas en GPU (5,7 MB en disco). Riesgo serio en Android gama media y Web (lo medido es en escritorio). Mitigar con compresión VRAM (ETC2/ASTC) o carga bajo demanda/mipmaps; medir en dispositivo.
3. GPU y draw calls no son problema ahora (85-134 draw calls, GPU <3 ms en modo real; 7-8 ms a 1080 en stress): un tema nuevo con shaders/sombras deberá re-medirse, sobre todo en iGPU y móvil.
4. `validate_state` (~1-1,7 ms) y `view_for` (~0,6-1,3 ms) son pequeños; no son prioridad.

## No medido
- Web y Android (no hay build): FPS reales, tiempo de carga < 10 s, memoria en móvil. Cómo: `bash tools/build.sh` (Web) y medir en el navegador con el panel Rendimiento de DevTools; en Android, export de depuración + `adb shell dumpsys gfxinfo <paquete>` y overlay de FPS. Pedir prueba manual al usuario.
- Tiempo de fotograma incluye el coste de la GPU integrada de esta máquina (Vega 10); extrapolar a móvil es "estimado", no medido.
- Desglose de `refresh()` por módulo y dispersión de los microbenchmarks de motor en un estado fijo.
