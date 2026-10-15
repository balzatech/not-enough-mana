# Plan de pruebas de la v0.3 (V3-05)

Autor: QA Agent. Fecha: 2026-10-14. Estado: plan sobre documentos; **no he ejecutado nada** en esta tarea ni existe aún el código de v0.3. Todo lo de abajo es "previsto", no "verificado".

Fuentes: `docs/revision/requisitos-v03-usuario.md` (R1-R8), `docs/revision/LINEAMIENTOS-v03.md` (§3.3 criterios 1-8, §7 prioridades 1-15, §8 puerta), `docs/diseno/v03-ataque-defensa.md` (CA-AT, CA-DF, CA-TM, CA-VC), `docs/diseno/escenarios/mesa-zonas-v03.md` (L-01 a L-17, fases F1-F8), `docs/TECNICO/v03-diseno.md` (contratos y tests §1.10, §2.3, §3.2), `docs/revision/revision-codigo-2026-10-14.md` (A1, A3, A4, M3, M4), `docs/qa/informe-v02.md`.

## 0. Convenciones

**Puertas** (cada una es una tarea de QA; lo no cubierto en una puerta se arrastra a la siguiente):
- **O1** = V3-18 (oleada 1: cimientos: A4, A1, M4, temporizadores, presentación, partida contra bots, A3).
- **O2** = V3-28 (oleada 2: mesa por zonas, ataque, defensa, relojes en pantalla; V3-27 deja listos los tests de ergonomía).
- **O3** = V3-36 (oleada 3: tema, packs, efectos, pantallas fuera de la mesa; V3-37 mide rendimiento).
- **Final** = V3-42 (oleada 4: los 7 puntos de LINEAMIENTOS §8) y **M12-bis** = V3-44 (usuario).

**Tipos de prueba:** `GUT` (test automático en `tests/**`, corre en `tools/test.sh`); `SIM` (`tools/sim.gd`, headless); `PERF` (`tools/perf/` o `tests/perf/`, Performance mide, QA verifica la cifra); `CAP` (captura a demanda con `tests/ui/capture*.gd`, QA mira las imágenes con Read; **es revisión visual de QA, no sustituye al usuario**); `HUM` (prueba humana M12-bis).

**Regla de honestidad:** en cada informe de puerta, QA separa "verificado" (ejecutado, con salida) de "revisado por lectura". Un `GUT` que no existe aún o que no falla al mutar el código no cuenta como cobertura: en cada puerta QA hace **mutación a mano** (en una copia del proyecto en el scratchpad, nunca en `src/`) de al menos los criterios de mayor riesgo (CA-TM-03, CA-VC-04, L-05, L-10, equivalencia A1) y comprueba que el test falla.

**Datos de partida comunes:**
- Reloj: siempre inyectado (`clock: Callable`, `auto_clock = false`, `tick(now)`), nunca `await` ni `Timer` reales.
- Semillas fijas: SIM `seed=1` (partidas 200) y `seed=1000` (repetición); tests dirigidos con semilla anotada en el propio test y en el mensaje de fallo.
- Estados dirigidos (fixtures en `tests/fixtures/`): ver §3 (mesa) y §4 (ataque/defensa).

**Archivos de test nuevos que propone este plan** (los demás son los que ya nombran los documentos de diseño): `tests/qa/test_invariantes_ui_v03.gd` (§3), `tests/qa/test_ergonomia_v03.gd` (V3-27, ya en TAREAS), `tests/qa/test_puertas_v03_*.gd` (V3-18/28/36/42, ya en TAREAS), `tests/qa/test_huerfanos_v03.gd` (§5, solo si `tools/test.sh` no basta), ampliaciones de `tools/sim.gd` (`--human-absent`, `--clock-policy`, `--potion-limit`; solo `tools/sim.gd`, que QA puede editar).

## 1. Cimientos (LINEAMIENTOS §7 bloque A) — puerta O1

| # | Hecho cuando | Prueba | Archivo | Datos / estado | Puerta |
|---|---|---|---|---|---|
| 1 (A4) | En un clon limpio `bash tools/test.sh` funciona a la primera | `HUM`-QA reproducible: `git clone` a una carpeta del scratchpad (sin `.godot/`), copiar solo lo versionado y ejecutar `bash tools/test.sh`; debe terminar sin error de `flock` ni de ruta. Repetir con `check_warnings.sh` | procedimiento en `docs/qa/puerta-o1-v03.md` | clon sin `.godot/` | O1 |
| 1 (A4) | Matar `check_warnings.sh` con `kill -9` no deja configuración que afecte al juego | Lanzar `check_warnings.sh` en segundo plano, `kill -9` a su PID, y comprobar: no existe `override.cfg` en la raíz del proyecto ni en ninguna ruta que Godot lea; arrancar el juego real (no headless) y revisar la consola: sin warnings convertidos en errores; `git status` no muestra `override.cfg` y `.gitignore` lo cubre. Además: dos `test.sh` simultáneos se serializan con `flock -w` y el segundo falla con mensaje (no cuelga) | procedimiento + `tools/test.sh` | PID matado a mano | O1 |
| 2 (A1) | `legal_actions(estado)` == `legal_actions(vista propia)` en ≥ 1000 estados; el espejo se ofrece en la interfaz | `GUT` de equivalencia (30 partidas, 3-6 jugadores, mínimos: ≥ 1000 estados x jugador, ≥ 50 con reacción abierta, ≥ 30 con prompts, ≥ 10 con artefacto activable; 5 fixtures dirigidas del diseño §3.2). QA añade: (a) mutación: reintroducir el borrado de `deck` en la vista y comprobar que falla; (b) **SIM** con comparación en cada paso en las 200 partidas por defecto (`tools/sim.gd --check-view`), que cubre muchos más estados que el GUT; (c) repro del bug original (mazo de 137, descarte vacío, Twardowsky's Mirror en mesa) por la **interfaz real** (`LocalUiDriver`): la acción aparece en el selector de la mesa; (d) `ActionOptions._add_hidden_choices` y `Bot._hidden_choices` retirados (`grep`) | `tests/engine/test_legal_view_equivalence.gd`; `tools/sim.gd`; `tests/qa/test_puertas_v03_o1.gd` | semillas del diseño; mazo 137 | O1 |
| 3 (M4) | Base común que restaura los estáticos; ruta `user://` de pruebas | `GUT`: test que muta cada estático (`CardCatalog.set_defs`, registro de efectos, `UiNav.*`, `UiUtil.prefer_extra/extra_defs`, `CardInfo.summaries_path/settings_path`) en un test A y comprueba en un test B (orden forzado, y orden inverso con `-gselect`/`-gunit_test_name`) que quedan restaurados. Comprobar que ningún test escribe en el `settings.cfg` real: `md5sum` del `user://settings.cfg` real antes y después de `test.sh`; idem la carpeta de datos del juego (`resumenes_corruptos.json`). Comprobar que los ≥ 25 tests que tocaban estáticos extienden la base (`grep -L "extends NemTest"`) | `tests/base/nem_test.gd`; `tests/qa/test_aislamiento_v03.gd` | `md5sum` previo | O1 |
| 3 (M4) | `tools/test.sh` falla si hay huérfanos y hoy da 0 | Ver **§5** (procedimiento completo) | `tools/test.sh` | línea base 3613 | O1 (y todas) |
| 4 | Temporizadores: turno vence -> `END_TURN` tras resolver lo pendiente | `GUT` CA-VC-01/02/03/11/12, CA-TM-10 | `tests/session/test_timers_v03.gd` | partida 3 jugadores, semilla anotada, reloj inyectado; `tick(now)` con `now` = inicio + plazo | O1 |
| 4 | Defensa vence -> `PASS_REACTION` / `DECLINE` | `GUT` CA-VC-04/05/08/10, CA-DF-09 (cadena Lightning: dos rondas, la segunda con plazo completo, un `tick` nunca resuelve dos rondas); T8-T12 uno a uno | `tests/session/test_timers_v03.gd`, `tests/engine/test_timeout_action.gd` | fixture "cadena Lightning" con el humano en `awaiting` dos veces; fixtures de prompts T8-T15 | O1 |
| 4 | Pausa mientras se espera a bots; no se reinicia con cada acción | `GUT` CA-TM-03, CA-TM-04, CA-TM-09, CA-AT-10: 30 s con 3 cartas jugadas a los 5, 12 y 20 s: vence a los 30 s de tiempo corrido; pausa de 10 s sin variación; reanudar con < 1 s restante da 1 s; hold `menu` pausa ambos relojes | `tests/session/test_match_clock.gd`, `test_timers_v03.gd` | reloj inyectado | O1 |
| 4 | "Sin límite" funciona; los bots no tienen plazo | `GUT` CA-TM-02, CA-TM-08; `ClockPolicy` no da reloj a bots ni a eliminados | `test_match_clock.gd` | `turn_timeout_ms = 0`, `defense_timeout_ms = 0` | O1 |
| 4 | 50 partidas con un humano que nunca actúa terminan sin bloqueo | `GUT` (CA-VC-09, 50/50) **y** `SIM --human-absent` ampliado a 200 partidas, 3-6 jugadores, con `randomness 0` y `15`; invariantes tras cada acción; contar que el humano no envió ni `REACT` ni `DRINK_POTION`; el tiempo de pared de la SIM no depende del plazo (reloj inyectado) | `test_timers_v03.gd`; `tools/sim.gd` | 50 partidas, seeds 1..50, y repetir con seed 1000 | O1, Final |
| 4 | Doble disparo y condiciones de carrera | `GUT`: dos `tick(now)` iguales -> un solo `TIMEOUT`; toque y luego `tick` -> `ERR_TIMEOUT_STALE` sin efecto ni error visible al jugador; `TIMEOUT` nunca en `legal_actions`; fin de partida durante un reloj no envía nada (CA-VC-12) | `test_timeout_action.gd`, `test_timers_v03.gd` | — | O1 |
| 4 (M3) | Reloj monótono | `GUT`: `LocalSession` usa `Time.get_ticks_msec` por defecto (la política recibe `now` como entero; `grep` de `get_unix_time_from_system` en `src/session/` = 0 ocurrencias en el camino de plazos) y un salto del reloj de pared simulado no altera el plazo (el reloj inyectado es lo único que cuenta) | `test_match_clock.gd` | — | O1 |
| 4 (M5) | `start()` reinicia todo; la cola avisa si descarta | `GUT`: dos partidas seguidas en la misma `LocalSession` sin restos (relojes, holds, cola); descarte de la cola emite aviso | `tests/session/test_local_session_restart_v03.gd` (nuevo, propuesto) | — | O1 |
| 5 | Los bots no adelantan a la presentación | `GUT` presentation: un bot no actúa con el bus ocupado y actúa al vaciarse; vigilancia de 4 s suelta el hold (el hold nunca bloquea la partida) | `tests/ui/test_presentation_v03.gd` | `auto_advance = false`, reloj inyectado | O1 |
| 5 | Retraso máximo de la cola <= 1,5 s en 3 y 6 jugadores | `GUT` `lag_ms <= 1500` con bots a 0 ms durante 200 acciones, 3 y 6 jugadores; **QA además lo mide con la mesa real** (juego no headless, 6 jugadores, volcado del máximo de `lag_ms` en una partida completa) | `test_presentation_v03.gd`; script de medida propuesto `tools/sim_lag.gd` (QA) | semillas 1 y 7 | O1 |
| 5 | Presupuesto por acción (900 ms; 400 ms con "Reducir animaciones"); ningún `refresh()` por feedback | `GUT` `hold_ms <= 900` y reducido `<= 400`; `refresh_count` sin cambios; la opción se guarda y se lee en la ruta `user://` de pruebas | `test_presentation_v03.gd` | — | O1, O3 |
| 5 | "Reducir animaciones" cumple §6.5 | `GUT`: con la opción, sin partículas, sin motas, sin giro del círculo rúnico, banners sin desplazamiento; **se mantienen** destellos, números flotantes y etiquetas >= 1 s. `CAP` con la opción activa (pedida en §8.7) | `tests/ui/test_reduced_motion_v03.gd` (nuevo, propuesto) | opción en `settings.cfg` de pruebas | O1 (lógica), O3 (visual) |
| 6 | Nueva partida solo permite 1 humano | `GUT`: el selector de humanos no existe o está fijo en 1 con `HOT_SEAT_ENABLED = false`; con `true` el comportamiento de v0.2 vuelve | `tests/ui/test_local_setup_v03.gd` | — | O1 |
| 6 | Límite de pociones desactivado por defecto y activable | `GUT` + `SIM --potion-limit` (default sin límite; `0` = sin límite; `N` = N). Defecto en `MatchPrefs` es `false`; se persiste | `test_local_setup_v03.gd`; `tools/sim.gd` | — | O1 |
| 6 | 200 simulaciones con valores por defecto: 200/200, 0 violaciones | `SIM --games 200 --seed 1` y `--seed 1000`, con la config por defecto de v0.3 (sin límite de pociones), comparando con `docs/qa/metricas-final.md`: terminadas 200/200, <= 4 partidas > 100 turnos, 0 > 200 turnos, 0 errores; **determinismo**: dos corridas idénticas con `cmp` | `tools/sim.gd` | seeds 1 y 1000 | O1, Final |
| 6 | Los tests de hot-seat siguen pasando | `GUT`: la suite actual completa; `grep` de que los tests de hot-seat (`test_local_session.gd`, `test_pass_device*`, etc.) no se han editado (git diff sobre ellos solo puede ser estructural de la base, ver §6) | suite | — | O1, O2, O3 |
| 13 (A3) | Caché de texturas arreglada; memoria medida antes/después | `PERF` Performance `tests/perf/perf_v03.gd` en 3 y 6 jugadores; QA **repite la medida** y compara con los ~280-290 MB de v0.2; criterio de §6.4: packs nuevos <= +20 MB sobre la medida tras A3. QA comprueba por lectura `grep "_tex_cache" src/` (o LRU con tope) y por ejecución que tras ir menú -> mesa -> menú -> mesa la memoria no crece sin límite (5 vueltas) | `tests/perf/perf_v03.gd`; `docs/rendimiento/v03-texturas.md` | 3 y 6 jugadores, 720 y 1080 | O1 (A3), O3 (+20 MB) |

## 2. Reglas del motor (acción `TIMEOUT`) y contrato de interfaz de relojes

| Elemento | Prueba | Archivo | Puerta |
|---|---|---|---|
| `MatchClock` y `ClockPolicy` puros, sin nodos | `GUT` puro: 30 s por turno completo en varias acciones; pausa de 10 s no consume; mínimo 1 s al reanudar; "Sin límite"; `key` nueva = plazo nuevo; puerta de arranque de la defensa; el menú pausa ambos; la presentación no pausa una defensa ya arrancada; bots sin reloj; eliminado sin reloj | `tests/session/test_match_clock.gd` | O1 |
| `TIMEOUT` en el motor: T1, T5->T1, T6, T7, T8-T12, T13 (misma semilla -> mismas cartas; distinta -> puede cambiar), T14, T15; `expect` caducado; `TIMEOUT` nunca legal; nunca bebe; `LOG_TIMEOUT` público | `GUT` | `tests/engine/test_timeout_action.gd` | O1 |
| `TIMEOUT` y determinismo/replay | `GUT` + `SIM`: reproducir una partida con `TIMEOUT` dos veces con la misma semilla da el mismo estado final; `Types.validate_state`, 154 cartas, vida 0-10, maná >= 0 y ida y vuelta JSON tras cada `TIMEOUT` | `test_timeout_action.gd`; `tools/sim.gd` | O1 |
| `TIMEOUT` no usado por bots ni expuesto a la vista de otro jugador | `GUT`: la vista de un rival no contiene el contenido del descarte aleatorio hasta que es público | `test_timeout_action.gd` | O1 |
| Estado estático / fugas de relojes entre partidas (M4, M5) | véase §1 filas 3 y M5 | — | O1 |

## 3. Mesa por zonas y ergonomía (LINEAMIENTOS §3.3 y L-01 a L-17) — puerta O2 (V3-27 deja los tests listos, V3-28 los ejecuta; se repiten en O3 y Final tras el cambio de tema)

**Generador de estados de mesa para los tests de disposición** (`tests/fixtures/table_states_v03.gd`, propuesto): construye una mesa real con `LocalSession` y fuerza cada fase F1-F8 de forma determinista, para N = 3, 4, 6 jugadores y las 4 resoluciones de §3.3.7 (720x1280, 1080x1920, 1080x2400, 720x1600; en el motor de pruebas se usa `Window.size` / `content_scale` como en `tests/ui/capture.gd`, con una de ellas leída de la ventana real al menos una vez). Estados por fase:

| Fase | Cómo se alcanza | Variantes |
|---|---|---|
| F1 Mi turno, sin selección | semilla fija; turno del humano; tras vaciar el bus | mano de 5 y de 7 cartas; con poción bebible y sin ella; con "nada jugable" (Terminar turno pasa a principal) |
| F2 Carta elegida sin objetivo | elegir un artefacto / Mana Orb | con pago y sin pago |
| F3 Eligiendo objetivo | elegir Fire Arrow | 1 objetivo válido, varios, con uno inmune (Campo de fuerza), con uno eliminado; 6 jugadores |
| F4 Confirmando / pagando | carta con coste extra | contador k/N; Confirmar deshabilitado y habilitado |
| F5 Defensa | hechizo contra el humano con respuestas | 1 respuesta, 4 respuestas, ninguna pagable, Mirror Shield (segundo paso), cadena Lightning |
| F6 Esperando bot | turno de un bot con retardo | respuestas de bot a mi hechizo |
| F7 Prompt obligatorio | descarte forzado, Magic Hand, Mana Focus, Elixir, Magic Cap, maná insuficiente | misma hoja que F5 (L-16) |
| F8 Fin / eliminado | humano a 0 de vida; fin de partida | eliminado en mitad de la ventana de reacción |

### 3.1 Los 8 criterios de §3.3

| Criterio | Prueba | Archivo | Puerta |
|---|---|---|---|
| 1 Zona del pulgar (centros >= 55 % de la altura; nada < 30 % salvo lista blanca) | `GUT` L-03 en F1-F5 x 4 resoluciones x N=3/4/6: recorre los controles de acción por tipo (grupo o metadato `action_kind`, no por texto) y comprueba `centro.y / H` | `tests/qa/test_ergonomia_v03.gd` (+ `tests/ui/test_zones_v03.gd` de V3-23) | O2, O3, Final |
| 2 Un solo principal | `GUT` L-07: en F1-F8 contar nodos visibles y no deshabilitados con `UiTheme.apply_primary` <= 1; **mutación**: añadir un segundo principal en copia y comprobar que falla | `test_ergonomia_v03.gd` | O2, O3, Final |
| 3 Nada que no aplique | `GUT` L-08: F6 y F8 con 0 botones de acción de turno en el árbol visible; F2-F4 sin Intercambiar/Descartar/Terminar turno. **"Visible" = `is_visible_in_tree()` y rect dentro del viewport y alpha > 0**, no solo `visible` | `test_ergonomia_v03.gd` | O2 |
| 4 Tamaños (144/96/144, separaciones 16/24, zonas 144x144 en apuntar) | `GUT` L-04 en todas las resoluciones, midiendo en px lógicos 1080 (`rect.size / s`); separación entre todos los pares de botones de una banda y distancia a Beber poción | `test_ergonomia_v03.gd` | O2, O3 |
| 5 Toques (<= 3 lanzar, 2 con un objetivo, defender <= 2, pasar 1, terminar 1) | `GUT` con `LocalUiDriver`: contar eventos de toque simulados hasta que sale la acción del motor. Casos: CA-AT-04/05, CA-DF-05, Recibir el golpe, Terminar turno, y **pago con cartas** (toques actuales + 0) | `tests/ui/test_attack_flow_v03.gd`, `test_defense_flow_v03.gd` | O2 |
| 6 Mano (>= 150 px/carta con 5 cartas en cualquier fase y N, con ficha abierta) | `GUT` L-05: rects de Z5, Z6, Z7 **idénticos (±1 px)** entre F1, F2, F3, F4, F6 y de Z5/Z7 en F5; ancho visible de cada carta >= 150·s. Es el test de regresión de QA-V2-35-06 | `test_ergonomia_v03.gd` | O2, O3 |
| 7 Pantallas (sin solapes, recortes ni texto < 22 px; margen superior >= 48 px) | `GUT` genérico por **invariantes de §3.2** (L-02, L-13) + `CAP` por fase | `test_invariantes_ui_v03.gd` | O2, O3, Final |
| 8 Respuesta al toque (pulsado en el mismo fotograma; "en proceso" hasta ver el resultado) | `GUT`: tocar con evento sintético y comprobar el estilo `pressed` en el mismo `_process`/frame (sin `await`); tras `PLAY_CARD` el botón queda en proceso (CA-AT-08: segundo toque no envía; recupera en <= 2 s con reloj inyectado si el motor no responde) y tras `REACT` igual (CA-DF-08). La **sensación** del toque es `HUM` | `test_attack_flow_v03.gd`, `test_defense_flow_v03.gd` | O2; HUM |

### 3.2 Invariantes de interfaz (recorren toda la UI visible en muchos estados)

Archivo propuesto: `tests/qa/test_invariantes_ui_v03.gd`, con un recorredor `UiInvariants.check(root, ctx) -> Array[String]` (en `tests/qa/ui_invariants.gd`, solo tests, no producción) que devuelve violaciones con **ruta del nodo, estado, resolución y N**. Se ejecuta sobre: las 8 fases F1-F8 de §3 x 4 resoluciones x N=3/4/6 x variantes; **todas las pantallas** (menú, nueva partida, Ajustes, Créditos, Cómo se juega, fin, Pasa el dispositivo si se conserva, diálogos); y un **recorrido aleatorio**: una partida completa por semilla (20 semillas, 3-6 jugadores) con un humano que juega con la política del bot y, tras cada cambio de fase de la mesa, ejecuta el recorredor. Así cubre combinaciones sin test específico.

| Invariante | Regla | Cómo se mide | Criterio que cubre |
|---|---|---|---|
| I1 Texto mínimo | ningún `Label`, `Button`, `RichTextLabel`, `LineEdit`, `OptionButton` visible con tamaño efectivo (override del tema, del nodo y escala acumulada) < `UiTheme.FONT_MIN` (22 px a 1080 lógico); falla con la ruta del nodo | recorrido del árbol + `get_theme_font_size`/override * escala | L-13, §3.3.7, v0.2 |
| I2 Texto sin cortar | para cada `Label`/`Button`/`RichTextLabel` visible: el tamaño del texto con la fuente (`Font.get_multiline_string_size` con `autowrap`/ancho del control) <= tamaño del control; `text_overrun_behavior` no es `TRIM`/`ELLIPSIS` activo con el texto realmente recortado; `clip_text` no recorta contenido; ningún `ScrollContainer` oculta un control de acción | cálculo geométrico | §3.3.7, L-02 |
| I3 Dentro de pantalla | todo `Control` visible con `mouse_filter != IGNORE` o con texto tiene su rect completamente dentro del viewport (±1 px), salvo los de listas con scroll declarado; el margen superior de controles interactivos >= 48·s | rects globales | L-02, L-13, §3.3.7 |
| I4 Tamaños de botón | botón interactivo visible >= alto mínimo de su nivel (principal 144·s, secundario 96·s, terciario zona 96·s, Pasar/Beber poción/Recibir 144·s); ancho táctil >= 96·s; el nivel viene de metadato o de `UiTheme.apply_*`; **un botón sin nivel declarado es una violación** (así se detectan botones nuevos sin criterio) | rects + metadatos | §3.3.4, L-04 |
| I5 Nada tapa vida/maná propios | el rect del panel de mi mago (Z5), y dentro de él los nodos de vida, maná y pociones, **no intersecan ningún otro `Control` visible con fondo opaco** que esté por encima en el orden de dibujo (hoja de defensa, banners, toasts, ficha, diálogos, etiquetas de resultado); escrim por debajo de Z5 en F5 | intersección de rects + orden de dibujo (`get_index`, `z_index`, capa) | L-11, L-05, §3.1 |
| I6 Zonas fijas entre fases | los rects de Z1, Z2, Z5, Z6, Z7 (y Z3/Z4 donde el diseño lo promete) son idénticos (±1 px) en cada par de fases, con el mismo N y resolución | tabla de rects por fase, comparación por pares | L-05, L-15 |
| I7 Sin solapes | ningún par de controles interactivos visibles se solapa (salvo padre-hijo); ningún par de zonas Z1-Z7 se solapa; hueco Z4-Z5 y Z5-Z6 >= 12·s | O(n²) por fase | L-02 |
| I8 Un principal / nada que no aplique | véase §3.1 criterios 2 y 3, ejecutado en el recorrido aleatorio | — | L-07, L-08 |
| I9 Contraste | texto >= 4,5:1 sobre su fondo efectivo (panel/estilo) para los estilos de tema; reutiliza `test_theme_constants`/`test_primary_text_contrast` ampliado a los 5 estados de botón y a los textos de relojes (oro, ámbar, carmesí, plata) y etiquetas de resultado | cálculo con colores del `StyleBox` | §2.2, V3-30 |
| I10 Significado no solo por color | cada etiqueta de resultado y cada estado de botón lleva texto o icono además del color (comprobable por nodo: `Label.text != ""` o `TextureRect.texture != null`) | árbol | §2.2, CA-TM-05 |
| I11 Estados vacíos honestos | ningún botón visible sin acción conectada (0 opciones muertas, V3-35): `Button.pressed` tiene conexión o el botón está oculto | `get_signal_connection_list` | §7 #14 |
| I12 Texto en español y sin claves crudas | ningún texto visible empieza por `LABEL_`/`B-`/contiene `{` `}` sin sustituir ni `%s`; sin inglés en frases propias de UI (lista de nombres de cartas excluida) | regex sobre textos del árbol | V3-21 |
| I13 Sin nodos duplicados fantasma | tras cerrar hoja/ficha/diálogo no quedan nodos visibles de la fase anterior (hoja de defensa fuera de F5, ficha fuera de F2-F4, timer de defensa fuera de F5) | árbol tras transición | L-12, L-08 |

Cada invariante viene con una prueba de que el recorredor **detecta** la violación (un nodo sintético que la comete) para que el recorredor no sea papel mojado. El recorrido aleatorio imprime semilla y paso al fallar. Gate: O2 los ejecuta con las pantallas de la mesa; O3 con todas las pantallas y el tema nuevo (los colores y fuentes cambian: I1, I2, I9 son las que más pueden romperse); Final repite todo.

### 3.3 Criterios L-01 a L-17 restantes

| Criterio | Prueba | Archivo | Puerta |
|---|---|---|---|
| L-01 Zonas (fórmulas de `y` y alto de Z3 según N) | `GUT` calcula `H_l`, `s` y compara con los rects reales en 4 resoluciones x N=3,4,5,6 (N=5 incluido porque Z3 vale 332) | `tests/ui/test_zones_v03.gd` | O2 |
| L-02 Sin solapes | I7 + I3 | `test_invariantes_ui_v03.gd` | O2, O3 |
| L-03 Pulgar | criterio 1 | `test_ergonomia_v03.gd` | O2 |
| L-04 Tamaños | criterio 4 | `test_ergonomia_v03.gd` | O2 |
| L-05 Mano estable | criterio 6 + I6 | `test_ergonomia_v03.gd` | O2 |
| L-06 Ficha en Z4 (contenida; N=6, H_l=1920: Z4 alto 336·s, contenido <= 324·s) | `GUT` rects con la carta de texto más largo (buscar en las 58 cartas la de máxima altura de ficha+preview+tira, no una elegida a mano) | `test_zones_v03.gd` | O2 |
| L-07 / L-08 | criterios 2 y 3 | `test_ergonomia_v03.gd` | O2 |
| L-09 Posición del principal (Lanzar, Confirmar, Terminar turno comparten rect; Beber poción comparte rect) | `GUT` rects | `test_zones_v03.gd` | O2 |
| L-10 Selector de objetivos == `legal_actions` | `GUT` y `SIM`: para cada carta con objetivo en F3 (todas las 58 jugables, cuando son jugables), el conjunto de chips/paneles resaltados == conjunto de objetivos de `legal_actions(estado)`; los demás con opacidad 0,45; el elegido con ✓; un único válido viene elegido. Depende de A1 (O1) | `test_attack_flow_v03.gd` | O2 |
| L-11 Hoja de defensa (no interseca Z5; alto <= 680·s; contenido obligatorio; botones >= 55 %) | `GUT` rects + textos | `test_defense_flow_v03.gd` | O2 |
| L-12 Relojes distintos (barra oro en Z1 vs anillo plata en la hoja; iconos y etiquetas distintos; nunca coexisten activos) | `GUT` árbol (CA-TM-05) + `CAP` | `tests/ui/test_clock_ui_v03.gd` | O2 |
| L-13 Textos | I1 | `test_invariantes_ui_v03.gd` | O2 |
| L-14 Resoluciones y jugadores | todo lo anterior parametrizado; `CAP` de N=6 a 720x1280 y 1080x2400 y N=3 a 720x1600 por fase F1-F8, **registrado en `docs/qa/capturas-v03.md`** con veredicto de QA por imagen (Read) | `tests/ui/capture_v03.gd` (propuesto), `docs/qa/capturas-v03.md` | O2, O3, Final |
| L-15 Panel de rival estable (no cambia de tamaño entre F1 y F3; contorno <= 6·s) | `GUT` rects | `test_zones_v03.gd` | O2 |
| L-16 Prompts (banda en Z6; Z7 con al menos una carta tocable simulando toque; Mana Focus/Elixir/Magic Cap/maná insuficiente usan la hoja de L-11) | `GUT` con toque sintético | `test_defense_flow_v03.gd` | O2 |
| L-17 Fin/eliminado (Z6 y Z7 ocultos; "Ver resultado" principal en `(H_l-104)·s`; fin: "Jugar otra vez" 144·s, "Menú principal" 96·s, centros >= 0,55·H) | `GUT` rects + CA-DF-15 | `test_zones_v03.gd` | O2 |

## 4. Ataque, defensa, temporizadores y vencimientos (docs/diseno/v03-ataque-defensa.md) — puerta O2 (lógica de sesión en O1)

### 4.1 Ataque (CA-AT)

| Criterio | Prueba | Archivo / datos | Puerta |
|---|---|---|---|
| CA-AT-01 temporizador de turno arranca al terminar el banner, valor configurado | `GUT` sesión + presentación, reloj inyectado | `test_timers_v03.gd`, `test_clock_ui_v03.gd` | O1, O2 |
| CA-AT-02 carta elegida -> dock solo Cancelar y Lanzar/Elige objetivo | `GUT` árbol (también I8) | `test_attack_flow_v03.gd` | O2 |
| CA-AT-03 resaltados == `legal_actions` | `GUT` + comprobación en SIM (ver L-10) | `test_attack_flow_v03.gd` | O2 |
| CA-AT-04 / 05 preselección y 2 / 3 toques | `GUT` con driver, cuenta de toques y acción enviada (`PLAY_CARD` con ese objetivo y ningún otro) | `test_attack_flow_v03.gd` | O2 |
| CA-AT-06 vista previa con carta, objetivo, `(si nadie responde)` y `Coste: N de maná`; frase nominal para las **58 cartas jugables** | `GUT` de cobertura recorriendo el catálogo: ninguna sin frase; texto sin claves crudas; exige coincidencia de coste con `Types`/`Game.effective_cost`. **Revisión humana de QA** de las 58 frases por lectura (listado impreso por el test a `docs/qa/frases-preview.md`): el test no sabe si la frase dice la verdad | `test_attack_flow_v03.gd`; tabla de V3-21 | O2 |
| CA-AT-07 carta de área sin paso de apuntar | `GUT` con las cartas de "todos" y "vecinos" | `test_attack_flow_v03.gd` | O2 |
| CA-AT-08 "en proceso", segundo toque no envía, recupera en <= 2 s | `GUT` con reloj inyectado | `test_attack_flow_v03.gd` | O2 |
| CA-AT-09 etiqueta por mago afectado >= 1 s + registro; ningún lanzamiento sin etiqueta | `GUT` `ResultLabeler` (secuencias de log a mano) **y** `SIM` con la mesa real: 200 acciones de ataque en partidas con el humano controlado por el bot; tras cada resolución, el bus emitió >= 1 etiqueta o aro de artefacto; ninguna acción de motor con efecto se queda sin etiqueta (contar eventos con efecto vs etiquetas) | `tests/ui/test_result_labeler_v03.gd`; `tools/sim.gd --labels` | O2 |
| CA-AT-10 pausa visible durante respuesta de bot | `GUT` + `CAP` | `test_timers_v03.gd`, `test_clock_ui_v03.gd` | O2 |
| CA-AT-11 pago en cartas: `Lanzar` solo tras `Confirmar` | `GUT` regresión del flujo v0.2 | `test_attack_flow_v03.gd` (y tests de pago ya existentes) | O2 |
| CA-AT-12 inmune: motivo `{M} tiene Campo de fuerza` | `GUT` | `test_attack_flow_v03.gd` | O2 |
| CA-AT-13 acción rechazada: `No se pudo lanzar: {motivo}`, carta sigue elegida | `GUT` forzando rechazo del motor (estado cambiado entre la elección y el envío) | `test_attack_flow_v03.gd` | O2 |

### 4.2 Defensa (CA-DF)

| Criterio | Prueba | Archivo / datos | Puerta |
|---|---|---|---|
| CA-DF-01 aviso `¡{atacante} te ataca!` con carta; borde carmesí | `GUT` árbol + `CAP` | `test_defense_flow_v03.gd` | O2 |
| CA-DF-02 área: número correcto de otros afectados | `GUT` | idem | O2 |
| CA-DF-03 sin `awaiting`: sin hoja ni reloj; B-SIN-DEF / B-SIN-PAGO >= 1 s y luego etiqueta | `GUT` con humano sin defensivas y con defensivas sin maná | idem | O2 |
| CA-DF-04 contenido de la hoja | `GUT` L-11 | idem | O2 |
| CA-DF-05 una respuesta preseleccionada, 2 toques; Recibir 1 toque | `GUT` driver | idem | O2 |
| CA-DF-06 respuesta no pagable atenuada con motivo; tocarla no selecciona | `GUT` | idem | O2 |
| CA-DF-07 beber poción no toca el reloj | `GUT` reloj inyectado: valor antes y después, mismo `key` | `test_defense_flow_v03.gd`, `test_timers_v03.gd` | O2 |
| CA-DF-08 `Defender` en proceso | `GUT` | idem | O2 |
| CA-DF-09 cadena = banner B-RESPONDE + plazo nuevo; única circunstancia de reinicio | `GUT` + SIM (ver §1 fila 4) | idem | O1, O2 |
| CA-DF-10 etiquetas BLOQUEADO / REDUCIDO −1 / IMPACTO −N / REFLEJADO (Frozen Bunny, Magic Shield sobre daño 3, impacto, Mirror Shield, Lightning) | `GUT` `ResultLabeler` con logs reales: se generan ejecutando el **motor real** con fixtures (no logs inventados) y se pasan al labeler; así si cambia el formato del log, falla | `test_result_labeler_v03.gd` | O2 |
| CA-DF-11 ANULADO con Annihilation, y **Annihilation sobre Annihilation** | `GUT` fixture dirigido | idem | O2 |
| CA-DF-12 Mirror Shield: Defender deshabilitado hasta elegir destino y defensiva a descartar | `GUT` | `test_defense_flow_v03.gd` | O2 |
| CA-DF-13 preferencia "solo si me afecta": sin aviso ni hoja; auto-pasa sin plazo | `GUT` + SIM con `--reaction affecting` (existente) | idem | O2 |
| CA-DF-14 "siempre": B-PUEDES en plata, consecuencia sin hablar de mí | `GUT` | idem | O2 |
| CA-DF-15 eliminación: IMPACTO −N y ELIMINADO >= 1 s antes de espectador | `GUT` + eliminación **durante la ventana de reacción** | idem | O2 |
| CA-DF-16 objetivo eliminado antes de resolver: SIN EFECTO | `GUT` | idem | O2 |

### 4.3 Temporizadores (CA-TM)

| Criterio | Prueba | Archivo | Puerta |
|---|---|---|---|
| CA-TM-01 defectos 30/20; opciones exactas 15/20/30/45/60/Sin límite y 10/15/20/30/Sin límite; persisten | `GUT` con `settings.cfg` de pruebas; incluye clave ausente -> defecto, corrupta -> defecto | `test_local_setup_v03.gd` | O1 |
| CA-TM-02 Sin límite: sin barra ni cifras, texto `Sin límite`, nunca `END_TURN` por tiempo | `GUT` | `test_timers_v03.gd`, `test_clock_ui_v03.gd` | O1, O2 |
| CA-TM-03 / 04 no reinicia / pausa | véase §1 | `test_match_clock.gd` | O1 |
| CA-TM-05 turno y defensa se distinguen por forma, icono, color, etiqueta y posición | `GUT` árbol (barra vs anillo, iconos distintos, colores distintos de la paleta, etiquetas distintas) + `CAP` | `test_clock_ui_v03.gd` | O2 |
| CA-TM-06 avisos de 10 y 5 s y toasts | `GUT` reloj inyectado: `Te quedan 10 s` solo en turno; defensa solo `Te quedan 5 s para defenderte`; cada aviso una sola vez | idem | O2 |
| CA-TM-07 redondeo hacia arriba, formato `m:ss`, nunca `0:00` antes de vencer | `GUT` barrido de ms: 30000..1 en saltos de 1 ms y comprobar la cadena (no solo ejemplos) | idem | O2 |
| CA-TM-08 bots sin reloj, retardo 600-900 ms | `GUT` + `SIM` (el retardo es inyectado; se verifica el rango del retardo calculado) | `test_timers_v03.gd` | O1 |
| CA-TM-09 menú abierto pausa defensa | `GUT` | idem | O1, O2 |
| CA-TM-10 toque posterior al vencimiento se descarta | `GUT` | idem | O1 |

### 4.4 Vencimientos (CA-VC)

| Criterio | Prueba | Archivo | Puerta |
|---|---|---|---|
| CA-VC-01 a 03 (turno vence: sin nada, con borrador, con prompt opcional propio) | `GUT` (más `TIMEOUT` en el motor) + `CAP` del mensaje B-TIEMPO-TURNO | `test_timers_v03.gd`, `test_timeout_action.gd` | O1, O2 |
| CA-VC-04 / 05 defensa y prompts opcionales: nunca `REACT`/`DRINK_POTION`/`USE_*` | `GUT` y SIM (contador) | idem | O1 |
| CA-VC-06 / 07 descarte forzado y elecciones obligatorias al azar con el RNG del estado, reproducible. **Pendiente de E15**: si el usuario decide otra cosa, el test cambia; hasta entonces se prueba lo que dice el diseño y se marca "provisional" | `GUT` misma semilla = mismo resultado; semilla distinta puede diferir | `test_timeout_action.gd` | O1 |
| CA-VC-08 varios prompts: plazo propio por prompt | `GUT` | `test_timers_v03.gd` | O1 |
| CA-VC-09 50 partidas con humano ausente | véase §1 fila 4; **y en la puerta final también con la mesa real** (juego no headless, 3 partidas con reloj acelerado inyectado) | `test_timers_v03.gd`, `tools/sim.gd` | O1, Final |
| CA-VC-10 cadena Lightning, dos rondas | `GUT` | idem | O1 |
| CA-VC-11 defensa dentro de mi turno vence, el turno reanuda con lo que quedaba | `GUT` | idem | O1 |
| CA-VC-12 fin de partida durante un reloj | `GUT` | idem | O1 |

### 4.5 Secuencias raras que QA añade (no están en los criterios, pero el proyecto las ha usado antes)

Todas como `GUT` dirigido con fixture y, si procede, `SIM` con mutaciones del plazo: Lightning encadenado con Mirror Shield; Annihilation sobre Annihilation; eliminación durante la ventana de reacción (el humano muere mientras su reloj de defensa corre); rebarajar con descarte vacío durante un `TIMEOUT` de descarte; evento robado en el reparto; Freeze al último jugador; Armageddon que mata a todos con un reloj abierto; humano eliminado mientras se espera al bot (el reloj del humano desaparece, no queda pausa colgada); cambio de configuración de tiempos en mitad de la partida (no debe aplicarse hasta la siguiente); cerrar el menú justo al vencer; dos humanos (hot-seat conservado) con relojes: el reloj corre solo para el que decide. Archivo: `tests/qa/test_secuencias_raras_v03.gd`. Puerta: O1 (sesión) y O2 (mesa).

## 5. Huérfanos (M4)

**Línea base:** 3613 nodos huérfanos en 23 avisos (`tests/ui/test_ui_scenes.gd` ~2466, `tests/ui/test_payment_text.gd` ~1146; más 1 `MainMenu` en `test_game_over.gd`, QA-V2-32-07). QA la reconfirma ejecutando `bash tools/test.sh` **antes** de V3-12 y guarda la salida en el scratchpad (no se versiona).

**Qué exige la puerta:**
1. `tools/test.sh` **informa**: al final imprime una línea `HUERFANOS: <n> en <m> tests` leída de la salida de GUT (parseo de "Orphans"/"orphan" en el resumen y por test) y **sale con código distinto de cero si `n > 0`**. Prueba de la prueba: QA crea en una copia un test que hace `Node.new()` sin liberar y comprueba que `test.sh` falla y nombra el test; luego lo libera y comprueba que pasa.
2. Valor admitido: **0 en la suite completa** al cerrar V3-12 (O1). Hasta entonces, el umbral por tarea: cualquier test **tocado o nuevo** en v0.3 debe tener 0 huérfanos (gate de O1, O2, O3, Final: se compara el listado de huérfanos por archivo con la lista de archivos cambiados en `git diff --name-only`); no se admite subir ningún archivo por encima de su cifra anterior.
3. QA verifica que el 0 es **real y no un silenciamiento**: (a) ningún cambio en la configuración de GUT que ignore huérfanos (`grep -rn "orphan" .gutconfig.json addons/ tests/base/ tools/test.sh`); (b) el 0 se mantiene con `-gexit` y sin él; (c) el mutante del punto 1; (d) tiempo de la suite no sube de forma anómala (si `free()` se ejecuta con `queue_free` diferido, hay que esperar un fotograma: se revisa el patrón `autofree`/`add_child_autofree`).
4. Al terminar cada puerta se registra la cifra en `docs/qa/puerta-*-v03.md`. Si un test nuevo de UI de v0.3 (las suites de 4 resoluciones x N x 8 fases construyen muchos nodos) deja huérfanos, es **bug de gravedad "grave" del test, no de producción**, y bloquea la puerta; se reporta al Developer dueño del test.
5. Corolario: tests de mesa de V3-27 y los invariantes de §3.2 deben liberar cada mesa en `after_each` (y con `await get_tree().process_frame` si es `queue_free`); QA los revisa antes de darlos por buenos porque él mismo es autor de los tests de invariantes.

## 6. Tests de v0.2 que cambian a propósito y cómo distinguir intención de regresión

**Esperados (de `v03-diseno.md` §1.9 y §8):**
| Test | Cambio esperado | Quién lo cambia |
|---|---|---|
| `tests/integration/test_local_table.gd::test_reaction_timeout_closes_modal` | con la mesa enlazada, la defensa no arranca hasta vaciar el bus: hay que añadir `t.feedback().bus.drain()` antes de comprobar el plazo | quien asigne el Producer en serie (no V3-14) |
| `tests/qa/test_puerta_o2.gd` (posible) | igual, si comprueba plazos con la mesa enlazada | idem |
| Tests que usan `reaction_timeout_local_ms`, `deadline_ms` o `check_timeouts` con la mesa enlazada | la API se conserva como alias (`check_timeouts` = `tick`) | revisar caso por caso |
| ~25 tests que tocan estáticos, `test_ui_scenes.gd`, `test_payment_text.gd` | cambian de base (`extends NemTest`) y se liberan nodos (M4) | V3-12 |
| Tests de legibilidad/disposición de v0.2 (`test_legibility.gd`, `test_ui_scenes.gd`) tras mover los botones por zonas | pueden necesitar rutas nuevas; **los valores de los criterios de v0.2 (144/96, 16/24 px, 22 px) no cambian** | V3-23/V3-32 |

**Cómo se distingue un cambio intencionado de una regresión (regla de QA):**
1. Un cambio en un test existente es **intencionado** solo si (a) está listado arriba o en el diseño, (b) el diff toca **la preparación** (añadir `drain()`, cambiar la base, ruta de nodo) y **no debilita ninguna aserción** (`assert_eq` -> `assert_true`, umbral relajado, `skip`, `pending`, test borrado o renombrado, `assert` eliminado), y (c) el mensaje de commit/tarea lo dice.
2. QA saca, en cada puerta, `git diff <commit v0.2>..HEAD -- tests/` **solo de archivos existentes en v0.2** y revisa línea a línea: conteo de aserciones por archivo antes/después (`grep -c "assert_"`), conteo de tests (`grep -c "func test_"`), número de `pending`/`skip`. Una bajada sin justificación = regresión del test (grave) y se reporta; el recuento total de la suite se compara con el de v0.2 (`informe-v02.md`): el total de tests solo puede subir.
3. **Mutación de confirmación:** para cada test editado a propósito, QA comprueba en una copia que el test sigue **fallando** cuando se deshace el comportamiento que protege (p. ej. `test_reaction_timeout_closes_modal`: si el plazo no cierra el modal, falla).
4. Los tests que **fallan sin estar en la lista** son regresión: bug en `docs/qa/bugs.md` con la semilla y el commit, no se arreglan tocando el test.
5. Los tests de hot-seat y de `LocalSession` sin mesa **no deben cambiar** (diff vacío o solo cambio de base); si cambian, se pide justificación.
6. Si una suite de tests v0.2 se rompe por una decisión de diseño legítima no prevista (p. ej. el nombre del botón ahora es otro), se trata como **escalado**: el Developer propone el cambio, QA lo verifica por mutación, y se anota en `docs/qa/` bajo "cambios de test justificados".

## 7. Rendimiento y memoria (Performance mide, QA verifica) — O1 (A3), O3 y Final

| Criterio | Prueba | Archivo | Puerta |
|---|---|---|---|
| Fotogramas con animación p95 <= 16 ms (duro), 3 y 6 jugadores, 720 y 1080 | `PERF`; QA repite una de las cuatro combinaciones por su cuenta y compara (tolerancia de ruido +-10 %) | `tools/perf/perf_v03_table.gd` | O3, Final |
| Fotograma con acción p95 <= 27 ms (6 jugadores, +2 tolerancia); meta 16 ms no es criterio | `PERF` | idem | O3, Final |
| Partículas <= 64 por efecto y <= 150 en pantalla; solo `CPUParticles2D`; shaders `canvas_item` sin `screen_texture` | `GUT` recorre los efectos y cuenta; `grep -rn "screen_texture\|GPUParticles" src/ assets/` = 0 | `tests/ui/test_effects_budget_v03.gd` (propuesto) | O3 |
| Acción completa <= 900 ms (400 reducido); turno de bot <= 4 s | `GUT` por `hold_ms` (§1 fila 5) + `PERF` con partida real | `test_presentation_v03.gd`, `perf_v03_table.gd` | O1, O3, Final |
| Memoria de texturas: tras A3 y +20 MB para packs | `PERF` | `perf_v03.gd` | O1, O3 |

## 8. Visual, licencias y pantallas fuera de la mesa — O3 y Final

| Criterio | Prueba | Archivo | Puerta |
|---|---|---|---|
| Contraste >= 4,5:1 por test | `GUT` I9 (más el test existente) | `test_invariantes_ui_v03.gd`, `test_theme_constants.gd` | O3 |
| DejaVu de respaldo y glifos españoles (á é í ó ú ü ñ ¿ ¡) en todos los `FontVariation` | `GUT` `test_glyph_fallback.gd` (existente, debe seguir verde) + `test_fonts_v03.gd` (Cinzel/título con DejaVu en `fallbacks`; `has_char` de las letras de títulos) | `tests/ui/test_fonts_v03.gd` | O3 |
| Fuente de título solo a >= 40 px a 1080, solo en textos cortos, nunca en números/registro/ficha | `GUT` árbol: toda `Label` con la fuente de título tiene tamaño >= 40 y texto <= 24 caracteres | `test_invariantes_ui_v03.gd` | O3 |
| Licencias: cada asset nuevo con su fila en `docs/arte/licencias.md` y su archivo de licencia; nada descargado sin aprobación; arte de las cartas sin modificar | `GUT`/script: recorre `assets/ui_v03/**` y comprueba que cada carpeta de pack tiene licencia y una fila en la tabla; hash (`sha256`) de todas las imágenes de cartas en `assets/` **idénticos a los de v0.2** (`git diff --stat` vacío sobre los PNG/WEBP de cartas); `docs/arte/descarga-v03.md` registra la aprobación del usuario por pack | `tests/qa/test_licencias_v03.gd` (propuesto) | O3, Final |
| Pantalla "Créditos y licencias" si algún pack exige atribución (CC BY) | `GUT` el texto de atribución de cada pack CC BY aparece en la pantalla | idem | O3 |
| Pantallas fuera de la mesa (menú, nueva partida, Ajustes, Cómo se juega con panel, fin): 0 opciones muertas; legibles en 720x1280 y 1080x2400 | `GUT` I1-I4, I11 + `CAP` | `test_invariantes_ui_v03.gd`; `capture_v03.gd` | O3 |
| Fondo propio de la mesa: motas <= 30, círculo rúnico <= 10 % de opacidad, sin motas con "Reducir animaciones" | `GUT` | `tests/ui/test_table_bg_v03.gd` (propuesto) | O3 |
| Botones con 5 estados distintos por forma, no solo por color | `GUT`: los StyleBox de normal/pressed/disabled/selected/busy difieren en al menos un atributo no cromático (borde, grosor, icono, offset) | `test_invariantes_ui_v03.gd` (I10) | O3 |
| Tanda de capturas del Director (§8.7): menú, nueva partida, mi turno, apuntar, vista previa, impacto, esperando a bot, defensa, defensa por tiempo, fin de turno por tiempo, eliminado, fin, Ajustes, "Reducir animaciones" | `CAP`; QA mira **cada** imagen con Read y anota qué ve y qué falla en `docs/qa/capturas-v03.md`; una imagen que no existe o que no se miró no se da por entregada | `tests/ui/capture_v03.gd` | Final |
| Conjunción astral (#15): especificación aprobada, tests, 200 simulaciones con la opción 200/200 | `SIM --astral`; `GUT` de regla; la opción desactivada por defecto no cambia las 200 SIM por defecto (cmp idéntico a la corrida sin la opción) | `tools/sim.gd`; test del Developer | Final (condicional; si no entra, se anota) |

## 9. Lo que no se puede probar automáticamente y cómo se cubre en M12-bis

Lo que ningún test de este plan certifica, aunque todo esté en verde:

| Aspecto | Por qué no es automatizable | Qué hace QA antes | Cómo se cubre en M12-bis (V3-44) |
|---|---|---|---|
| Estética ("¿se ve como un juego de magos?", coherencia de paleta, packs, marcos, fondo) | juicio subjetivo; el usuario pidió identidad visual como criterio | capturas por fase y pantalla, revisadas con Read; QA anota solo defectos objetivos (desalineado, borroso, ilegible, ruido) | pregunta de §8 "¿Se ve como un juego de magos? ¿Algo sigue pareciendo una aplicación?", por pantalla; veredicto del usuario manda |
| Ergonomía táctil real (alcance del pulgar, comodidad, toques accidentales) | con ratón en PC no hay pulgar; los tests miden posición y tamaño, no comodidad | los 8 criterios de §3.3 como umbrales objetivos (centro >= 55 %, 144/96 px, separación 16/24) | pregunta "¿Encontraste cada control donde lo esperabas?" + hoja de registro (toques fallidos, búsquedas); **limitación conocida:** confirmación táctil real en v0.4 (Web en red local en el celular) |
| Legibilidad en el celular (tamaño físico, brillo, sol, distancia) | los px lógicos no equivalen a mm reales; el contraste medido es matemático | I1/I9 y capturas a 720x1280 y 1080x2400; guía: informar de la densidad de píxeles equivalente | el usuario juega con la ventana a tamaño de celular (720x1280) y responde "¿Supiste siempre a quién atacabas...?"; en v0.4, en el aparato |
| Claridad del combate (¿se entiende quién atacó a quién y si se ejecutó?) | los tests verifican que existe la etiqueta, no que se entiende | CA-AT-09 / CA-DF-10 con el motor real; capturas de A1-A6 y D0-D3 | preguntas de claridad y defensa; "Aprobado" exige "sí" en ambas |
| Ritmo y sensación de los relojes (30 s y 20 s) | los valores son parámetros; si "se sienten bien" es subjetivo | valores, avisos y diferenciación comprobados | pregunta "¿30 s de turno y 20 s de defensa se sienten bien? ¿Se distinguen los dos relojes?" |
| Animaciones: ayudan o estorban | presupuesto en ms se mide; la molestia, no | `hold_ms`, `lag_ms`, cuadros por segundo (PERF) | pregunta "¿Las animaciones ayudan o estorban? ¿Esperaste de más?"; también con "Reducir animaciones" |
| Diversión y calidad de los bots | cualquier métrica de partida es proxy | SIM (terminan, duración, empates, victorias por asiento) | "¿Volverías a jugar contra los bots?"; si "no/a veces", v0.3.1 con bots |
| Daltonismo y accesibilidad real | solo se prueban relaciones de contraste y que el color no sea el único significado | I9, I10 | opcional: el usuario indica si algún estado le confunde |
| Texto del producto (naturalidad del español) | el test detecta claves crudas y huecos, no la calidad del texto | I12 y listado de frases para lectura (`frases-preview.md`) | comentarios libres del usuario durante las partidas |
| Sección 8 de los requisitos "Evitar interfaces confusas" (texto cortado, E10) | no se sabe qué más pedía | se aplica I1-I13 como proxy | se pide al usuario que complete o descarte la sección en E10 |

**Cómo se prepara la prueba humana (guion V3-41):** dos partidas (3 y 5 bots) a 720x1280 y, si puede, 1080x2400; las preguntas de LINEAMIENTOS §8 **por pantalla y por fase** (no una pregunta global), con una hoja de registro: minutos jugados, toques fallidos, búsquedas de un control, esperas, momentos de confusión, y marca de las fases F1-F8 vividas. Antes de entregarle la build, QA ejecuta la puerta final completa y entrega una lista corta de defectos conocidos para que no los repita el usuario. QA **no** puede aprobar esta parte: solo registra la respuesta del usuario. Veredicto según LINEAMIENTOS §8: "sí" en claridad y ubicación -> aprobado; "a veces/no" -> aprobado con cambios (v0.3.1).

## 10. Calendario de puertas y salida de cada una

| Puerta | Debe estar en verde | Entregable QA |
|---|---|---|
| **O1** (V3-18) | `bash tools/test.sh` verde y **0 huérfanos**; `check_warnings.sh` sin warnings; clon limpio; equivalencia A1 (GUT + SIM); 200/200 SIM por defecto + 50-200 con humano ausente; temporizadores (§1 fila 4, §2, §4.3 y §4.4 en lo de sesión); presentación (cola <= 1,5 s); partida contra bots; memoria antes/después | `docs/qa/puerta-o1-v03.md`, `tests/qa/test_puertas_v03_o1.gd`, `bugs.md` |
| **O2** (V3-28) | Todo O1 + §3 (8 criterios, L-01 a L-17, invariantes sobre mesa) + §4 (CA-AT, CA-DF, CA-TM, CA-VC en pantalla) + capturas F1-F8 | `docs/qa/puerta-o2-v03.md`, `capturas-v03.md` |
| **O3** (V3-36) | Todo O2 repetido con el tema nuevo + §7, §8 (contraste, glifos, licencias, pantallas, efectos) | `docs/qa/puerta-o3-v03.md` |
| **Final** (V3-42) | Los 7 puntos de LINEAMIENTOS §8: pruebas completas, 200 SIM + 50 humano ausente, §3.3, relojes, rendimiento, licencias, tanda de capturas; reejecución completa tras cualquier corrección | `docs/qa/informe-v03.md` con Aceptar / Aceptar con reservas / Rechazar |

Regla de regresión tras cada corrección: reejecutar el caso fallido, la suite completa, `check_warnings.sh` y la SIM de 200 (determinismo con `cmp`); informar qué se ejecutó, qué falló y qué no se pudo ejecutar.

## 11. Tabla final: criterio, prueba, archivo, puerta

| Criterio | Prueba | Archivo | Puerta |
|---|---|---|---|
| #1 A4 clon limpio / `kill -9` | HUM-QA procedimiento | `docs/qa/puerta-o1-v03.md` | O1 |
| #2 A1 equivalencia estado/vista (>= 1000 estados) | GUT + SIM + repro por UI | `tests/engine/test_legal_view_equivalence.gd`, `tools/sim.gd` | O1 |
| #3 M4 aislamiento + 0 huérfanos (base 3613) | GUT + `tools/test.sh` falla con n>0 + mutante | `tests/base/nem_test.gd`, `tests/qa/test_aislamiento_v03.gd`, `tools/test.sh` | O1 y todas |
| #4 temporizadores en la sesión (turno/defensa/pausa/Sin límite/bots) | GUT reloj inyectado | `test_match_clock.gd`, `test_timers_v03.gd`, `test_timeout_action.gd` | O1 |
| #4 50 partidas con humano ausente | GUT + SIM | `test_timers_v03.gd`, `tools/sim.gd` | O1, Final |
| #4 M3 reloj monótono; M5 `start()` reinicia | GUT | `test_match_clock.gd`, `test_local_session_restart_v03.gd` | O1 |
| #5 cola <= 1,5 s, presupuesto 900/400 ms, bots no adelantan | GUT + medida con mesa real | `test_presentation_v03.gd` | O1, O3 |
| #5 "Reducir animaciones" §6.5 | GUT + CAP | `test_reduced_motion_v03.gd` | O1, O3 |
| #6 un humano, pociones sin límite por defecto, hot-seat conservado | GUT | `test_local_setup_v03.gd` + suite hot-seat | O1 |
| #6 200/200 SIM por defecto, determinismo | SIM | `tools/sim.gd` | O1, Final |
| #7 mesa por zonas: §3.3.1-3 (pulgar, un principal, nada que no aplique) | GUT 4 res x N 3/4/6 x F1-F8 | `test_ergonomia_v03.gd`, `test_zones_v03.gd` | O2, O3, Final |
| §3.3.4 tamaños | GUT | `test_ergonomia_v03.gd` | O2, O3 |
| §3.3.5 toques | GUT driver | `test_attack_flow_v03.gd`, `test_defense_flow_v03.gd` | O2 |
| §3.3.6 mano >= 150 px, zonas estables | GUT | `test_ergonomia_v03.gd` | O2, O3 |
| §3.3.7 sin solapes/recortes/texto < 22 px | GUT invariantes I1-I3, I7 + CAP | `test_invariantes_ui_v03.gd` | O2, O3, Final |
| §3.3.8 respuesta al toque / en proceso | GUT; sensación HUM | `test_attack_flow_v03.gd`, `test_defense_flow_v03.gd` | O2; M12-bis |
| Nada tapa vida/maná propios (I5, L-11) | GUT invariante | `test_invariantes_ui_v03.gd`, `test_defense_flow_v03.gd` | O2, O3 |
| L-01, L-06, L-09, L-15, L-17 | GUT rects | `test_zones_v03.gd` | O2 |
| L-10 objetivos == `legal_actions` | GUT + SIM | `test_attack_flow_v03.gd` | O2 |
| L-12 relojes distintos | GUT árbol + CAP | `test_clock_ui_v03.gd` | O2 |
| L-14 capturas por fase y resolución | CAP | `capture_v03.gd`, `capturas-v03.md` | O2, O3, Final |
| L-16 prompts | GUT con toque | `test_defense_flow_v03.gd` | O2 |
| #8 flujo de ataque A1-A6 | GUT + CAP | `test_attack_flow_v03.gd`, `test_result_labeler_v03.gd` | O2 |
| CA-AT-01..13 | GUT (04/05 por toques; 06 cobertura 58 cartas) | `test_attack_flow_v03.gd`, `test_timers_v03.gd`, `test_clock_ui_v03.gd` | O1/O2 |
| #9 flujo de defensa D0-D3; CA-DF-01..16 | GUT + CAP | `test_defense_flow_v03.gd`, `test_result_labeler_v03.gd` | O2 |
| #10 relojes en pantalla, avisos 10 s y 5 s, pausa visible, mensaje al vencer; CA-TM-01..10 | GUT + CAP | `test_clock_ui_v03.gd`, `test_timers_v03.gd`, `test_local_setup_v03.gd` | O1, O2 |
| CA-VC-01..12 | GUT + SIM | `test_timers_v03.gd`, `test_timeout_action.gd` | O1 |
| Secuencias raras (Lightning+Mirror, Annihilation x2, eliminación en ventana, rebarajar sin descarte, evento robado, Freeze al último, Armageddon) | GUT dirigido | `test_secuencias_raras_v03.gd` | O1, O2 |
| #11 packs: propuesta sin descarga, solo los aprobados | script de licencias + lectura de `licencias.md`/`descarga-v03.md` | `test_licencias_v03.gd` | O3, Final |
| #12 tema: contraste >= 4,5:1, glifos, fuente título, memoria, Créditos | GUT + PERF | `test_invariantes_ui_v03.gd`, `test_fonts_v03.gd`, `test_glyph_fallback.gd`, `perf_v03.gd` | O3 |
| #13 efectos §6.1 visibles; rendimiento §6.3 (p95 <= 16 ms animación; 27 ms acción) | CAP + PERF + GUT presupuesto | `capture_v03.gd`, `perf_v03_table.gd`, `test_effects_budget_v03.gd` | O3, Final |
| #14 pantallas fuera de la mesa, 0 opciones muertas | GUT I11 + CAP | `test_invariantes_ui_v03.gd`, `capture_v03.gd` | O3 |
| #15 Conjunción astral (condicional) | SIM + GUT | `tools/sim.gd`, test del Developer | Final |
| §8.1 test, warnings, 0 huérfanos | `tools/test.sh`, `check_warnings.sh` | suite | todas |
| §8.7 tanda de capturas del Director | CAP + Read | `capturas-v03.md` | Final |
| Tests v0.2 que cambian a propósito | revisión de diff + mutación | §6 | todas |
| Estética, ergonomía táctil real, legibilidad en celular, diversión | HUM M12-bis | `docs/qa/guion-m12bis.md` | V3-44 |

## 12. Riesgos y huecos del propio plan

- **No hay código de v0.3 todavía**: los nombres de archivo y de API (`MatchClock`, `ClockPolicy`, `TIMEOUT`, `ResultLabeler`, `TableDock`, etc.) vienen de los diseños; si cambian, se actualiza el plan, no se baja el criterio.
- **CA-VC-06/07 dependen de E15 y E11** (decisión del usuario sobre elegir al azar al vencer en decisiones obligatorias); se prueba lo escrito y se marca "provisional".
- **Mesa en headless**: los rects de los tests de disposición dependen de que la escena se instancie con tamaño correcto sin ventana; QA ya usa `tests/ui/capture.gd` para ello, pero una resolución puede comportarse distinto en el juego real: por eso L-14 incluye siempre capturas ejecutadas con el juego **no headless** al menos una vez por puerta.
- **Tiempo de la suite**: 4 resoluciones x 3 N x 8 fases x variantes + recorrido aleatorio puede alargar `test.sh`; si pasa de ~3 min, el recorrido aleatorio y las variantes pasan a un archivo `tests/qa/test_invariantes_ui_v03.gd` ejecutado solo en las puertas (`-gselect`), pero la parametrización base (1 resolución por defecto en la suite normal) sigue en `tools/test.sh`. Esa decisión se anota en el informe de la puerta.
- **Tests que dependen de `Time.get_ticks_msec` real**: `grep` de `OS.delay_msec`, `await get_tree().create_timer` y `Time.` en `tests/`; cualquiera que dependa del reloj real en tests de v0.3 es defecto de test.
- **Pendiente de confirmar por los autores del diseño**: tolerancias de ±1 px (L-05) frente a escalado no entero; si "visible" en I3 excluye controles dentro de `ScrollContainer` (el diseño dice que el registro desplegado es una zona táctil); formato exacto de las líneas de registro para el `ResultLabeler` con logs reales.
