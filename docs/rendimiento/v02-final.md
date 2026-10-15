# V2-34 Medición final de la mesa (después de feedback animado, tema nuevo, iconos de estado, ficha, fin y ayuda)

Fecha 2026-10-13. Sin cambios de código de producción (solo `docs/rendimiento/` y `tools/perf/`). Misma máquina y método que `v02-base.md` (V2-20): Godot 4.7.2, gl_compatibility, Mesa 26.0.3, AMD Radeon Vega 10 (iGPU), Wayland :0, vsync desactivado y `max_fps=0`; render a SubViewport 1080x1920 o 720x1280 con `size_2d_override` 1080x1920; semilla 11; p1 humano jugado por el script con `Bot.choose_action`, resto bots; **3 repeticiones por configuración, cada una en un proceso nuevo, bajo `flock .godot/nem-godot.lock`, sin la suite ni otro agente usando la CPU**. Datos crudos en `tools/perf/` (ver "Reproducir"). Todo lo de abajo es medido salvo lo marcado "estimado".

## Veredicto contra el presupuesto

| Criterio | Umbral | Medido (modo real, 4 configuraciones) | Resultado |
|---|---|---|---|
| Fotogramas con animación en curso y sin acción, p95 | <= 16 ms | 2,7 / 3,0 / 2,9 / 3,2 ms (p99 3,1-3,6) | **cumple** |
| Fotograma con acción, p95 | <= 57 ms | 24,4-26,8 ms (máx. 27,7-33,7) | **cumple** |
| Idem, objetivo | <= 33 ms | 24,4-26,8 ms | **cumple** |
| **Meta final de v0.2: fotograma con acción p95 <= 16 ms** | <= 16 ms | **24,4-26,8 ms (p50 13,2-16,7)** | **NO cumple** (1,5-1,7 veces el presupuesto; entre el 32 % y el 53 % de los fotogramas con acción pasan de 16 ms) |

Cambios frente a la base: p95 con acción -53 a -55 %, p50 -60 a -65 %, máximo -50 %. Frente a lo que midió QA en la puerta O2 (25,8-29,0 en 3j; 25,8-27,8 en 6j) no hay regresión por V2-33 (tema, rejillas 5-6, botón de 144 px, resumen de ficha, fin y ayuda): 25,1 en 3j y 26,8 en 6j.

**Causa de que no se llegue a 16 ms (medida).** Ya no es `refresh()`. El fotograma con acción de un bot, en media (3j / 6j, 1080): motor+IA del bot 3,3 / 6,3 ms (en el 5 % peor de 6j: **20,8 ms**), `refresh()` 4,1 / 5,3 ms, resto de la señal (vista, opciones, avisos) 1,2 ms, coste base de un fotograma vacío 2,2 ms, maquetación y dibujo diferidos ~1,6 ms. En fotogramas con acción **del humano** se suma `FeedbackLayer.play` (4,2 ms de media en 3j; 8,6 ms en el 5 % peor), que es lento por una causa concreta y barata de arreglar: el glifo ▼/▲ no está en la fuente por defecto y cada número flotante hace una búsqueda de fuente del sistema (ver abajo). Ordenado por ganancia esperada: (1) fuente con ▼▲ empaquetada, (2) sacar la decisión del bot del fotograma, (3) recortes de `refresh()`. Con (1)+(2) el p95 estimado en 3 y 6 jugadores baja a ~15-18 ms en esta máquina; **estimado, no medido**; en un móvil gama media será mayor.

## Reproducir

```
# Matriz completa (3j y 6j x 1080 y 720 x real 30 s y stress 15 s, mas ui y leak, 3 repeticiones): ~25 min, GPU real, nada mas corriendo
DISPLAY=:0 bash tools/perf/run_v02_final.sh > /tmp/perf_v02_final.txt
python3 -I tools/perf/aggregate_final.py /tmp/perf_v02_final.txt          # media, sd, min, max de cada campo

# Una sola configuracion (modos: real | stress | ui | leak)
DISPLAY=:0 flock .godot/nem-godot.lock godot --path . -s tools/perf/perf_final.gd -- <jugadores> <ancho> <alto> <modo> <segundos> [semilla]
NEM_LEAK_GAMES=10 DISPLAY=:0 flock .godot/nem-godot.lock godot --path . -s tools/perf/perf_final.gd -- 6 1080 1920 leak 60 11

# Complementos
DISPLAY=:0 flock .godot/nem-godot.lock godot --path . -s tools/perf/perf_ablate.gd -- 3 1080 1920 real 30 11 <none|hand|log|rivals|center|own|all>
DISPLAY=:0 flock .godot/nem-godot.lock godot --path . -s tools/perf/perf_layer.gd -- 3 1080 1920 real 1 11    # desglose de FeedbackLayer.play
DISPLAY=:0 flock .godot/nem-godot.lock godot --path . -s tools/perf/perf_glyph.gd                              # coste del glifo ▼▲ y arreglo simulado
flock .godot/nem-godot.lock godot --headless --path . -s tools/perf/perf_bot.gd -- <3|6> 8 1                    # coste por accion de bot, sin UI
flock .godot/nem-godot.lock godot --headless --path . -s tools/perf/perf_objects.gd -- 6                        # deriva de objetos sin UI
```
Crudos (eliminados del repositorio el 2026-10-14 por limpieza; se regeneran con los comandos de arriba): `v02-final-raw.txt` (matriz final, 48 ejecuciones), `v02-final-raw-run1.txt` (primera pasada idéntica, antes de añadir p99 y los contadores de fotogramas > 16 ms), `v02-final-ablate-raw.txt`, `v02-final-bot-raw.txt`. `perf_final.gd` no edita `src/`: usa `TableScreen.profile_refresh`/`refresh_profile` (ya existían) y sustituye en el árbol las conexiones de `TableSync.on_state_changed`, `PresentationBus.ingest`, `FeedbackLayer.play` y del temporizador de bots por envoltorios que cronometran y llaman a lo mismo.

Definiciones: "fotograma con acción" = el que contiene un `state_changed` (igual que V2-20). "Con animación sin acción" = fotograma sin `state_changed` con el bus con items pendientes o la capa con números/destellos activos (~50 % de todos los fotogramas). Con ~45-57 fotogramas con acción por ejecución, **el p95 lo fijan los 3 peores**: desviación entre repeticiones 0,3-1,9 ms; entre la pasada 1 y la final hubo hasta 2,7 ms de diferencia en 6j (29,5 frente a 26,8). Léase "26 ± 2 ms".

## Antes / después (V2-20 frente a hoy; ms por fotograma; media de 3 repeticiones, sd entre paréntesis)

| Métrica | Base 3j 1080 | Hoy 3j 1080 | Base 3j 720 | Hoy 3j 720 | Base 6j 1080 | Hoy 6j 1080 | Base 6j 720 | Hoy 6j 720 |
|---|---|---|---|---|---|---|---|---|
| p50 de todos los fotogramas | 2,1 | 2,2 (0,0) | 1,8 | 1,8 (0,0) | 2,3 | 2,2 (0,0) | 2,0 | 2,1 (0,1) |
| p95 de todos los fotogramas | 2,9 | 3,0 (0,1) | 2,6 | 2,6 (0,0) | 3,2 | 3,1 (0,0) | 2,9 | 2,9 (0,1) |
| p95 con animación sin acción | n/d | 3,0 (0,1) | n/d | 2,7 (0,1) | n/d | 3,2 (0,0) | n/d | 2,9 (0,1) |
| Con acción p50 | 38,3 | **13,6 (0,6)** | 38,0 | **13,2 (0,1)** | 42,2 | **16,7 (1,0)** | 41,5 | **16,4 (0,6)** |
| Con acción p95 | 54,8 | **25,1 (1,9)** | 52,4 | **24,4 (0,3)** | 56,7 | **26,8 (0,8)** | 56,6 | **25,6 (0,7)** |
| Con acción máx | 60,8 | 31,3 (2,4) | 59,2 | 27,7 (0,7) | 67,6 | 33,5 (1,9) | 64,7 | 33,7 (3,7) |
| Con acción p95 sin la decisión del humano* | n/d | 23,0 (0,8) | n/d | 21,6 (1,0) | n/d | 26,8 (0,8) | n/d | 25,1 (0,1) |
| Fotogramas con acción > 16 ms | todos | 20 de 57 | todos | 18 de 57 | todos | 24 de 45 | todos | 23 de 45 |
| `refresh()` por llamada, en partida | 32,9 (aislado) | 4,0 (0,1) | n/d | 3,9 (0,1) | 28,7 (aislado) | 5,3 (0,4) | n/d | 5,1 (0,1) |
| `submit_action` humano completo (reduce+vista+señales+refresh) | 25,5 | 6,0 (0,2) | n/d | 5,8 (0,1) | 20,9 | 6,9 (0,1) | n/d | 6,6 (0,3) |
| Instanciar `table.tscn` | 10,6 | 17,9 (0,8) | n/d | 19,3 (1,2) | 12,0 | 19,8 (2,2) | n/d | 19,4 (1,5) |
| Primer `bind_session`+refresh | 7,6 | 8,1 (0,6) | n/d | 8,6 (0,7) | 11,3 | 11,8 (1,3) | n/d | 11,7 (0,9) |

\* La decisión del humano (`Bot.choose_action`, 3-4 ms por acción suya) la toma el script en el hilo principal; una persona real no la paga ahí. La base la incluía, así que la fila principal es comparable; esta fila es la cifra de juego real.

Modo `stress` (retardo de bot 0; es **una partida completa**: 90 fotogramas en 3j, 223 en 6j, no 15 s como en la base, donde la partida ya había terminado): p50 14,5 / 16,6 y p95 27,8 / 30,5 ms (3j / 6j, 1080), 27,2 / 31,1 a 720. Base: p50 49-54 y p95 93-110 ms (~19 fps). Máximos 34,6 (3j) y 53,2 ms (6j).

### Recursos

| Recurso | Base 3j / 6j | Hoy 3j / 6j | Cambio |
|---|---|---|---|
| Nodos de la mesa (inicio) | 153 / 191 | 180 / 221 | +27 / +30 |
| Nodos totales, `OBJECT_NODE_COUNT` (inicio) | 171 / 213 | 208 / 251 | +37 / +38 |
| Nodos totales al final de la partida (modo real / stress) | n/d (183 / 241 en stress, al inicio) | 230 y 325 / 264 y 398 | crece con el registro y la pantalla de fin |
| Draw calls p50 (modo real) | 85-87 / 130-134 | 96 / 143 | +7 a +10 % |
| Draw calls p50 (stress, feedback activo) | n/d | 171 / 394 | nuevo |
| GPU del viewport p50 / p95, 1080 (real) | 1,5 / 2,1 / 1,3 / 1,7 | 1,4 / 1,9 / 1,4 / 1,7 | igual |
| GPU en stress p50, 1080 / 720 | 7,5 y 3,6 / 6,8 y 3,4 | 6,6 y 3,4 / 7,3 y 3,9 | igual (p95 9,6-9,9 a 1080) |
| Texturas cargadas (.webp) | 172 | 188 (+16) | las nuevas son pequeñas |
| Memoria de texturas tras cargar | 288 MB (1080) / 279 (720) | 288,1 / 279,3 | **igual** |
| Memoria de texturas al final de una partida | n/d | 295,0 (1080) / 281,2 (720) | +7 MB (1080) tras dibujar |
| `MEMORY_STATIC` tras cargar / al final | 52 / 68-71 MB | 56,3 / 69-73 MB | +4 / +1 |
| VRAM (`RENDER_VIDEO_MEM_USED`) | 300 (1080) / 290 (720) | 305,5 / 291,8 | +5 / +2 |

Las texturas **no han crecido** (≈ 290 MB en GPU sigue siendo el riesgo grande para móvil y Web, ver Propuestas P7); la memoria estática crece 4 MB en la carga.

## Desglose del fotograma con acción (modo real, 1080; ms; media de 3 repeticiones)

`refresh()`, `sync` y capa están medidos con relojes; "motor+IA del bot" = temporizador de bots − cadena de señales; "resto" = fotograma − todo lo anterior (coste base del fotograma, maquetación y dibujo diferidos, `PresentationBus._process`, tweens). La suma es exacta por construcción.

| Componente | 3j media | 3j peor 5 % | 6j media | 6j peor 5 % |
|---|---|---|---|---|
| **Fotograma con acción (total)** | 14,9 | 28,0 | 17,8 | 29,9 |
| Señal `state_changed` → `TableSync` (vista, `ActionOptions`, avisos, **`refresh()`**) | 5,3 | 7,5 | 6,6 | 5,3 |
| de ello `refresh()` | 4,1 | 5,7 | 5,3 | 4,6 |
| Mapper + `PresentationBus.ingest` | 0,04 | 0,05 | 0,03 | 0,05 |
| `FeedbackLayer.play` (solo cuando arranca en ese fotograma: acciones del humano) | 1,3 | **8,6** | 0,2 | 0,0 |
| Motor + IA del bot (decisión, 2 `Game.reduce`, estado) | 3,3 | 0,0 | 6,3 | **20,8** |
| Motor del humano (reduce y vista de su acción) | 0,2 | 1,1 | 0,1 | 0,0 |
| Decisión del humano (script, no real) | 1,0 | 4,1 | 0,6 | 0,0 |
| Resto (base del fotograma, maquetación/dibujo diferidos, bus, tweens) | 3,8 | 6,6 | 4,0 | 3,8 |
| (informativo) CPU de render del viewport / GPU | 0,8 / 1,5 | 0,8 / 1,5 | 1,0 / 1,5 | 1,1 / 1,5 |

Lectura: el 5 % peor de 3j son **acciones del humano** (capa con los números flotantes + decisión del script); el 5 % peor de 6j son **decisiones de bots caras** (20,8 ms de media en esos fotogramas). Con 3 fotogramas por ejecución en el extremo, esto es lo que decide el p95 y por eso las dos mejoras principales son distintas.

`refresh()` por módulo, ms por llamada (media de todas las llamadas de la partida, 1080):

| Paso | 3j | 6j | Qué es |
|---|---|---|---|
| menú (turno, botón de regla) | 0,04 | 0,06 | |
| **registro (`ActionLog.set_entries`)** | **1,48** | **2,61** | 37-49 % de `refresh()`; RichTextLabel con las 3 últimas entradas |
| paneles (rivales + propio) | 0,77 | 0,81 | `update_player` en sitio, firmas |
| centro (mazo, descarte) | 0,58 | 0,40 | |
| botones de acción | 0,26 | 0,24 | |
| mano (`HandView` + ficha) | 0,74 | 1,11 | reconstruye los `CardView` en cada refresh |
| avisos / prompts / fin | 0,11 | 0,10 | |
| **Total** | **3,98** | **5,34** | base: 28-43 ms |

Otras mediciones del bus de feedback (fixture: partida tras 25 acciones del humano, semilla 11): `FeedbackMapper.map_entry` de todo el registro (59 entradas) 0,25-0,32 ms; `PresentationBus.ingest` de 6 entradas 0,05 ms; el bus **no** es un coste. Refrescos disparados por el feedback: 0 (QA lo verifica con test; aquí `refresh_count` = 1,00-1,04 por fotograma con acción).

### Causa medida de `FeedbackLayer.play`: el glifo ▼/▲

`FeedbackLayer.play` cuesta 2,5-3,5 ms por número en estado estable en `perf_layer.gd` (hasta 6 ms; 26 ms la primera vez); en partida, tras las 10 primeras llamadas, 6,4 ms de media en 3j y 4,0 en 6j (máx. 17 y 11 ms). En el desglose de `play`, `FloatingText.reset_size()` es 2,48 ms de cada llamada y el resto de pasos <0,1 ms. `tools/perf/perf_glyph.gd`: forma del texto de un número flotante (ms por texto nuevo, media):

| Texto | Fuente por defecto (hoy) | Con la fuente de respaldo explícita (simulada, DejaVu) |
|---|---|---|
| `-3` | 0,04 | 0,04 |
| `▼ -3` | **3,71** | 0,06 |
| `▲ +3` | **5,80** | 0,07 |
| `▼ -3 maná` | **3,96** | 0,09 |
| `Bloqueado` | 0,06 | 0,08 |

La fuente del tema es la de serie de Godot y no incluye ▼ ▲ (`UiTheme.GLYPH_DAMAGE/HEAL`, solo los usa `FloatingText`): cada texto recurre a la búsqueda de fuentes del sistema, 40-80 veces más lenta que con la fuente de respaldo. Además es un riesgo de **corrección** en Web y Android (no medido): allí no hay garantía de que el sistema tenga un glifo ▼▲ (podría verse un recuadro vacío justo en el indicador de forma pensado para daltonismo). Esto es coherente con los picos del fotograma en que el bus arranca la animación de una acción de bot (el siguiente al de la acción; los fotogramas con acción de bot registran `layer` = 0): en 30 s hay 2-3 fotogramas "con animación sin acción" > 16 ms (máx. 20,7-24,1 ms); el p95/p99 de esos fotogramas (3,0 / 3,5 ms) no lo ve.

Ablación (`perf_ablate.gd`: ocultar un subárbol de la mesa; 2 repeticiones, ruido ~±1 ms): ocultar **los cinco bloques a la vez** (mano, registro, rivales, centro y panel propio) baja el "resto" de 4,3 a 2,7 ms (3j) y de 4,7 a 2,8 ms (6j), y el fotograma vacío de 2,3-2,5 a 1,5-1,8 ms: **la maquetación y el dibujo diferidos de toda la mesa valen ~1,5-1,9 ms**; cada bloque suelto queda dentro del ruido (<1 ms; el mayor, los rivales en 6j, -0,9 ms). Por eso la maquetación/dibujo no es el cuello de botella, y la contingencia que anota `ARQUITECTURA.md` ("siguiente paso = pool de `CardView`") **no se justifica**: la mano entera cuesta 0,7-1,1 ms de `refresh()`.

## Coste de abrir la ficha, el zoom, la ayuda y la pantalla de fin (`perf_final.gd ... ui`, ms; media de 3 repeticiones; "fotograma" = el siguiente completo, con maquetación y dibujo; fotograma vacío 2,2-3,1)

| Acción | 3j 1080 | 3j 720 | 6j 1080 | 6j 720 | Nodos añadidos |
|---|---|---|---|---|---|
| Ficha: `show_info` | 0,91 | 0,81 | 0,83 | 0,80 | 2-4 |
| Ficha: fotograma siguiente (media / **primera vez**) | 4,0 / **17,2** | 3,6 / **17,7** | 4,6 / **16,5** | 4,3 / **17,4** | |
| Zoom: `show_zoom` (carta grande + resumen) | 1,32 | 1,20 | 1,31 | 1,19 | 0 netos (sustituye al anterior) |
| Zoom: fotograma siguiente (media / primera vez) | 3,4 / 3,9 | 2,7 / 2,3 | 3,9 / 3,7 | 3,3 / 3,8 | |
| **Ayuda**: `open_help` | **21,1** | 20,7 | 20,3 | 20,9 | 39-41 |
| **Ayuda**: 2 fotogramas siguientes (suma) | **25,1** (máx. 32) | 20,5 | 24,0 | 20,7 | |
| Ayuda: cerrar (`close_help`, hasta el fotograma siguiente) | 11,8 | 7,5 | 11,4 | 7,0 | |
| **Fin de partida**: construcción (señal con `check()`; una acción normal cuesta ~5,5) | 9,3 | 9,7 | 9,8 | 10,6 | **+55 (3j) / +83-86 (6j)** |
| de ello el paso `check()` dentro de `refresh()` | 3,8 | 3,6 | 4,6 | 5,2 | |
| Fin: fotograma en que aparece | **33,0** | 34,8 | 28,1 | 32,1 | |
| Fin: reabrir resultado (`show_result` + fotograma) | 0,17 + 4,2 | 0,16 + 3,3 | 0,22 + 4,7 | 0,22 + 4,5 | |
| Fin: `MatchSummary.build` / `GameOverSummary.show_summary` | 0,10 / 1,9 | 0,08 / 1,7 | 0,14 / 3,1 | 0,14 / 3,7 | |
| Mesa nueva enlazada a una sesión ya terminada (`bind_session`) | 10,7 | 10,6 | 14,8 | 17,4 | |

Ninguna ocurre dentro del flujo de acción, pero **la ayuda tarda 41-46 ms en abrirse (tres fotogramas por encima de 16 ms) y la pantalla de fin hace un fotograma de ~28-35 ms**: tirones aislados, de un solo uso por partida; la ficha y el zoom son baratos (la primera ficha de la sesión, 17 ms, es el primer dibujo en frío de sus etiquetas). Prioridad baja.

## Fugas: 3 partidas seguidas en la misma sesión (y 10 de comprobación)

`perf_final.gd ... leak`: por partida, se crea `LocalSession` + `table.tscn`, se juega hasta el final (bots; p1 por script), se libera la mesa (`queue_free`) y se cuenta tras 5 fotogramas. Semillas 11, 12, 13 (distintas); todas terminan (15-65 acciones del humano).

| | Antes (línea base) | Tras partida 1 | Tras partida 2 | Tras partida 3 |
|---|---|---|---|---|
| **Nodos** (3j y 6j, 1080 y 720) | 2 | **2** | **2** | **2** |
| Nodos huérfanos | 0 | 0 | 0 | 0 |
| Recursos (`OBJECT_RESOURCE_COUNT`) | 258 | 276 | 276 | 276 |
| `MEMORY_STATIC` MB (3j 1080) | 56,3 | 65,9 | 65,6 | 66,0 |
| Memoria de texturas MB (3j 1080) | 288,1 | 295,4 | 295,3 | 295,3 |
| Objetos (3j 1080) | 1781 | 1873 | 1874 | 1876 |

**No hay fuga de nodos**: tras cada partida el árbol vuelve a los 2 nodos de partida; el pico dentro de una partida es 289-398 nodos (3j: 289-339; 6j: 373-398) y se libera por completo. La subida de la primera partida (+18 recursos, +9,7 MB estáticos, +2,4-7,3 MB de texturas, ~+100 objetos) es de una sola vez (cachés de fuentes, tema, ayuda) y no se repite: la memoria estática queda plana (65,5-66,3 MB en 10 partidas). **Deriva menor**: `OBJECT_COUNT` sube +1,3 objetos por partida en 3j y +3,7 en 6j (10 partidas: 1873 -> 1885 y 1872 -> 1906) sin nodos, sin recursos y sin memoria apreciable. Sin interfaz (`perf_objects.gd`, solo sesión y motor, 10 partidas) el contador es **plano** (1512), así que la deriva viene de la capa de UI (no es del motor); impacto: despreciable hoy; conviene vigilarla en partidas largas (QA/Developer, ver P8).

## Cuellos de botella restantes y propuestas (medibles, priorizadas; **ninguna aplicada**)

Estimaciones sobre las cifras de arriba; cada una indica cómo comprobarla con los scripts de `tools/perf/`.

| # | Propuesta | Dueño | Ganancia esperada (estimada a partir de lo medido) | Cómo verificarla |
|---|---|---|---|---|
| **P1** | Empaquetar una fuente pequeña (subconjunto con ▼ ▲) como fuente de respaldo explícita del tema, o dejar de usar el glifo en el texto | Technical Artist (+ Art para la fuente) | `FloatingText.play` 2,5-6 ms -> ~0,1 ms por número: -4,2 ms de media y hasta -8 ms en el 5 % peor de los fotogramas con acción del humano (3j); elimina los picos de 5-16 ms del primer fotograma de cada animación de bot; arregla además el glifo en Web/Android. Esfuerzo bajo | `perf_glyph.gd` (3,7-5,8 -> 0,06-0,09 ms ya demostrado con DejaVu del sistema como simulación) y `perf_final.gd` real: `layer_after10_mean_ms` 4,0-6,4 -> ~0,3 y `hum_layer` |
| **P2** | Quitar la decisión del bot del fotograma de la UI: (a) no validar con `Game.reduce` y volver a reducir en `_apply` (dos reduces por acción de bot); (b) calcular la decisión en un hilo (`WorkerThreadPool`, sobre una copia del estado) o repartirla en fotogramas y aplicar la acción en el siguiente | AI Programmer + Lead Programmer (`LocalSession`, `Bot`) | El paso del bot sin UI cuesta p50 3,1 / p95 8-9 / máx. 16-34 ms (`perf_bot.gd`, 8 partidas: decisión p50 0,8-1,1, p95 4,4-6,2, máx. 11-23 ms; `Game.reduce` p50 0,8, p95 2,2-2,4). (a) -0,8 ms p50 y -2,2 ms p95 por acción de bot; (b) quita toda la decisión del fotograma: -3,3 ms de media en 3j, -6,3 en 6j, y **-20 ms** en el 5 % peor de 6j. Es la palanca principal para llegar a 16 ms en 6 jugadores. Esfuerzo medio (b), bajo (a) | `perf_final.gd real` (`m_engine_bot`, `tail_engine_bot`, `active_ms_p95`) y misma semilla = mismo resultado de partida (`tools/sim.gd --games 200 --seed 1` idéntico) |
| **P3** | `ActionLog.set_entries`: no volver a crear las líneas de la franja si las 3 últimas no cambian de contenido; actualizar solo el texto; evitar `str(last)+str(names)` y el parseo de BBCode en cada refresh | Developer (UI) | -1 a -2 ms por `refresh()` (el registro es 1,48 / 2,61 ms de 4,0 / 5,3) | `refresh_call_log` en `perf_final.gd real` |
| **P4** | `HandView.set_hand`: no reconstruir los `CardView` si la mano, la selección, lo jugable y el ancho no cambian (la mayoría de las acciones de bots no tocan la mano del humano); `ActionOptions.build` solo cuando el que mira puede decidir | Developer (UI) | -0,7 a -1,1 ms (mano) y hasta -0,9 ms (`legal_actions` en 6j cuando es el turno del humano) por acción de bot | `refresh_call_hand` y `fx_action_options_ms` |
| P5 | Ayuda: construir las 8 secciones al abrir en 2-3 tandas, o reutilizar la instancia oculta; fin de partida: construir el resumen un fotograma después de la señal | Developer (UI) | De 41-46 ms a ~3 fotogramas de ~15 ms; fin de partida de 28-35 a ~16-20 ms. Una sola vez por uso | `perf_final.gd ui` (`help_*`, `gameover_*`) |
| P6 | **No hacer** el pool de `CardView` que sugería `ARQUITECTURA.md` como contingencia: la mano es 0,7-1,1 ms y toda la maquetación diferida ~1,5-1,9 ms | Lead Programmer | Ganancia <= 1 ms por la complejidad de un pool | ablación `perf_ablate.gd` |
| P7 | Memoria de texturas: ~290 MB en GPU (288 a 1080, 279 a 720) con las 188 imágenes; sin cambios desde la base. Compresión de textura (ETC2/ASTC para Android, S3TC/Web según plataforma) o carga bajo demanda | Technical Artist / Build | No medible aquí: hace falta el dispositivo. Estimado: 3-4x menos VRAM con compresión con pérdida | Medir en Android (`dumpsys meminfo`) y Web |
| P8 | Deriva de objetos de UI (+1,3 a +3,7 por partida): localizar qué clase se retiene (tweens/`Callable`s de la capa de feedback o estáticos de UI) con `Object.get_orphan_node_ids`/`print_orphan_nodes` o `--verbose` + `ObjectDB` en una partida larga | Developer (UI) / QA | Sin impacto hoy | `NEM_LEAK_GAMES=10 ... leak` debe dar `objects` plano |

Con P1 y P2(b) el fotograma con acción de 6j pasaría de 17,8 ms de media a ~11-12 ms y el peor 5 % de ~30 a ~10-13 ms más sus picos de capa; el p95 esperado queda en ~15-18 ms en esta máquina (**estimado**). Llegar de forma holgada a 16 ms exige además P3/P4 (-2 a -3 ms) y, para móvil, medir en el dispositivo.

Otro dato para decidir: los 2,2 ms de un fotograma vacío (con GPU 1,4 ms) son coste fijo del motor + la mesa y no están en el presupuesto de cada acción.

## No se pudo medir y cómo hacerlo

- **Web y Android (FPS, carga < 10 s, memoria en móvil): no medido** (no hay build ni dispositivo en esta máquina). Todo lo de arriba es escritorio con una iGPU Vega 10. Cómo: Web, `bash tools/build.sh` y panel Rendimiento de DevTools (FPS, memoria JS/WASM, tiempo de carga a "Jugar"); Android, export de depuración y `adb shell dumpsys gfxinfo <paquete> framestats` (jank), `adb shell dumpsys meminfo <paquete>` (memoria gráfica) y overlay de FPS. **Se pide al usuario la prueba manual** con una partida de 6 jugadores (modo real) en un móvil gama media y en el navegador.
- Extrapolación a móvil, **estimada, no medida**: la CPU de un móvil gama media suele ser 2-4 veces más lenta que este escritorio en código GDScript; con ese factor, un fotograma con acción de ~25 ms pasaría de 50 ms, es decir P1 y P2 son necesarios, no opcionales, para esa plataforma.
- El glifo ▼▲ en Web/Android: la ausencia de fuente de sistema se deduce de que Godot Web no accede a fuentes del SO; no he visualizado el resultado.
- Eventos con muchas animaciones simultáneas en móvil (394 draw calls en 6j en stress, GPU 6,6-7,3 ms p50 a 1080 en esta iGPU): riesgo de relleno de pantalla en GPU de móvil; no medido.
- Un valor atípico en la primera pasada (6j 720, una ejecución con p95 de todos los fotogramas 6,9 ms y 9550 fotogramas en 30 s en vez de ~13400) no se repitió en la pasada final: se atribuye a actividad externa de la máquina y está en `v02-final-raw-run1.txt`.
- Los microbenchmarks de motor sobre un estado fijo (fixture: tras 25 acciones del humano, semilla 11), stress, 3j / 6j: `Game.reduce` 0,73 / 0,66 ms; `legal_actions` 0,06 / 0,09; decisión de bot 0,31 / 0,24; `Types.view_for` 1,18 / 1,47; `Types.validate_state` 1,45 / 1,74 ms (la base daba 0,85/0,62 y 1,2/0,96 sobre estados distintos, no comparables). Para el coste del bot en partida completa vale `perf_bot.gd` (arriba), que es la cifra representativa.
