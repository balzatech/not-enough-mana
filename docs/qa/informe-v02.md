# Informe de la puerta final de v0.2 (V2-35) - QA independiente

Fecha 2026-10-13. Godot 4.7.2, máquina libre (8 núcleos, GPU AMD Vega 10, `DISPLAY=:0`). "Ejecutado" = lo corrí yo en esta puerta; "lectura" = no ejecutado. No acepté los informes de los agentes: repetí tests, simulaciones, mediciones y capturas (leídas con Read a 720x1280 y 1080x1920). No edité `src/`, `data/`, `assets/`, `tools/` ni tests de otros; solo `tests/qa/test_puerta_final.gd`, `docs/qa/*` y `docs/revision/capturas/v2-35-*`. Detalle de métricas en `docs/qa/metricas-final.md`; defectos en `docs/qa/bugs.md`.

## Recomendación al Director: **APROBAR v0.2 CON RESERVAS** (ninguna bloqueante)

Los cuatro ítems cuya caída implica "rechazado" según LINEAMIENTOS §6 (1, 3, 7 y 9) **pasan** con evidencia propia; los ítems 10-12 (cuya caída implicaría "aprobado con cambios") también pasan, tres de ellos con reservas menores. Suite verde y estable, 0 warnings, simulaciones deterministas con todos los criterios de V2-42 cumplidos, rendimiento dentro del presupuesto (no la meta de 16 ms). Lo que queda abierto son 8 defectos menores/cosméticos nuevos o reabiertos (`QA-V2-35-01` a `08`), ninguno bloqueante. Falta lo que nadie puede hacer sin humanos ni dispositivo: **M12** (el criterio "¿supiste siempre qué te pasó?" del Director) y todo lo de móvil, Web y Android (§8).

Reservas por orden de importancia:
1. **QA-V2-35-03 (menor, ítem 6):** "Vibración: sí/no" en Ajustes es una opción muerta (nada la lee). Es lo único que impide cerrar "interfaz honesta" sin reserva.
2. **QA-V2-35-04 (menor, ítem 12):** la ventana de reacción con 6 jugadores tapa vida, maná y pociones propios (los prompts del motor sí los dejan visibles).
3. **QA-V2-35-02 (menor, ítem 4):** el descarte forzado sigue diciendo "Descarta 2 carta(s)" (QA-V2-03-03 se había dado por cerrado: reabierto).
4. **QA-V2-35-06 (menor, ítems 5/12):** con 6 jugadores y la ficha abierta la mano queda diminuta.
5. **QA-V2-35-01 (menor):** el botón transparente del registro está a 8 px de "Menú" (§2.1 pide 16).
6. **E6 (decisión del usuario, no bloquea):** sigue habiendo 1 partida de 140 turnos con un mago a 10/10 pociones y 0 de maná; con `randomness` 15 (corrida de la puerta O3, no repetida) reaparecía en 2 partidas.
7. Meta de 16 ms por fotograma con acción **no cumplida** (20,0 ms en 3j y 27,2 ms en 6j, p95); sí el criterio (<= 57) y el objetivo (<= 33).

## 1. Batería (ejecutado)

| Comando | Resultado |
|---|---|
| `bash tools/test.sh` al llegar (sin mis tests) | 55 scripts, **689/689**, 12 766 asserts, 177 s |
| `bash tools/test.sh` con `tests/qa/test_puerta_final.gd` (corrida A) | 56 scripts, **712 tests: 708 pasan + 4 pendientes** (los 4 defectos vigilados, 0 fallos), 15 960 asserts, 187 s |
| `bash tools/test.sh` (corrida B, idéntica) | idéntica: 712 / 708 + 4 pendientes / 15 960 asserts, 187 s; la lista de tests de A y B coincide línea a línea (`diff`) |
| `bash tools/check_warnings.sh` | **OK: sin warnings**, código de salida 0 (la primera vez detectó un `tr` que sombreaba un método de `Object` en mi test; corregido) |
| Mis tests solos: `-gselect=test_puerta_final` | 23 tests: 19 verdes + 4 `pending` (defectos abiertos, ver §6), 3 194 asserts, 13 s |
| Arranque del juego real: `godot --path . --quit-after 300` con pantalla (Mesa, Vega 10) | salida 0, consola limpia (solo la línea de versión y del dispositivo OpenGL) |
| Recorrido real en ventana (script del scratchpad, no SubViewport): menú -> "Jugar local" -> "Empezar" -> mesa de la configuración por defecto, humano jugado con `Bot.choose_action`, bots con sus temporizadores | partida completa de 15 turnos en 43,6 s, pantalla de fin visible, **0 errores y 0 warnings en consola** |

Estabilidad: 5 ejecuciones completas de la suite en total (1 sin mis tests, 2 provisionales con una versión anterior de mis tests y 2 finales) sin ningún fallo intermitente; el fallo "sin nombre" de QA-V2-32-08 **no se reprodujo**. Orphans: `1 Orphans` en `test_game_over` y varios cientos de nodos por test en `test_payment_text`, `test_ui_scenes` y `test_legibility` (cosmético, QA-V2-32-07, no afecta al producto).

**Efecto lateral que causé y corregí:** la primera versión de mi `test_f_item5_*` (y, probablemente, mi captura del zoom) abría el zoom y eso escribió `hold_hint_seen=true` en el `settings.cfg` **real** del usuario (`~/.local/share/godot/app_userdata/Not Enough Mana/settings.cfg`), con lo que en el juego real dejaba de salir la pista "Mantén pulsada una carta". Lo detecté (al ejecutar la mutación en la copia, que comparte ese directorio de usuario), retiré la clave a mano y el test usa ahora un archivo temporal (`CardInfo.settings_path`). Comprobado tras las corridas A y B y tras mis tests solos: el archivo queda igual (`[audio] [ui] vibration=true`), así que **ninguno de los demás tests existentes lo escribe**. Nota: ese `settings.cfg` conserva claves `[audio] music=7 sfx=7` de una versión antigua (sin efecto).

### Tests propios y mutaciones (copia del proyecto en el scratchpad; nunca en el original)

`tests/qa/test_puerta_final.gd` (23 tests) cubre lo nuevo con un método distinto al de los tests de cada tarea:

| Qué | Test | Cómo lo comprueba |
|---|---|---|
| V2-33: 0 textos < 22 px | `test_f_no_text_under_22px_in_3_5_6_player_tables`, `..._dialogs_and_reaction_sheet_of_6_players` | recorre **todos** los Control visibles del árbol (Label, Button, RichTextLabel, StatChip, también cada panel de jugador) en mesas de 3, 5 y 6 con estados, 8/10 pociones, prompts y reacción |
| V2-33: botones | `test_f_buttons_sizes_and_gaps_in_3_5_6_...`, `..._forced_discard_bar_and_reaction_sheet` | todo `Button` visible: principales (Jugar, Intercambiar, Descartar, Terminar, Beber poción, Confirmar, Pasar) >= 144 y el resto >= 96 (escala 720); **todas las parejas** de botones >= 16 px y >= 24 junto a Beber poción; dentro de la pantalla |
| V2-33: botón principal con estilo | `test_f_primary_button_has_own_color_and_border_distinct_from_secondary` | fondo y borde distintos del secundario, borde >= 4 px, contraste >= 4,5:1, un único principal en el menú, Beber poción conserva su color |
| V2-33: iconos de estado | `test_f_status_icons_are_48px_textures_distinct_and_no_old_text_tags` | iconos de 48 px con textura, una distinta por estado (Bot, Congelado, Cegado, Escudo, Eliminado, Turno), ningún rótulo antiguo de texto |
| V2-33: diálogos | `test_f_dialogs_never_cover_own_hp_mana_chips_3_and_6_players` | la hoja y la barra no intersecan los StatChip propios |
| V2-33: mesa de 5-6 | `test_f_rival_panels_do_not_overlap_...` | paneles sin solape; imprime la altura del panel propio (769 / 851 / 935) |
| P1 | `test_f_p1_fallback_font_has_every_symbol_the_ui_code_uses`, `test_f_p1_license_ships_...` | **escanea `src/ui/**/*.gd`** y exige que cada símbolo usado (▼ ▲ ⚠ → ✓ · …) exista en la fuente del tema y en `DejaVuSans.ttf`; sin búsqueda de fuente del SO; licencia con "Bitstream" |
| P2 | `test_f_p2_exactly_one_reduce_per_bot_action_over_full_games`, `..._old_flow_is_exactly_twice_and_final_state_is_identical`, `..._with_a_human_and_affecting_mode_...` | partidas completas de 3, 4, 5, 6 bots (con la configuración **por defecto** de la sesión): `reduce_calls == acciones`; el flujo antiguo da 2x; estado final, historial y `rev` idénticos; con humano y auto-pase |
| Ítems 3, 4, 5, 8 | `test_f_item3_...fire_storm...`, `test_f_item4_...`, `test_f_item5_...`, `test_f_item8_...` | coste efectivo con Fire Storm ("Maná: 2 (base 1)"), "jugable == existe PLAY_CARD", texto de pago exacto y preselección con 1 y con 2 combinaciones, "Ver" abre el zoom con un toque y la pista de pulsación larga, "Jugar otra vez" conserva jugadores y opciones con semilla nueva |
| Ítem 5 y 6 | `test_f_screens_have_no_dead_buttons_and_no_underscore_texts`, `test_f_table_scenarios_...` | menú, ajustes, ayuda, configuración local, pasa-el-dispositivo y 8 escenarios de mesa: 0 botones sin conexión, 0 textos con `_`, ninguno de "Crear sala", "Música", "Efectos", alto >= 96/144 |
| Defectos vigilados | `test_f_menu_and_log_strip_gap`, `test_f_open_defect_*` (3) | `pending` mientras el defecto exista; pasan solos al corregirse |

**Mutaciones manuales (6, copia del proyecto; los tests fallan en todas, y vuelven a pasar al restaurar):**

| # | Mutación en la copia | Resultado |
|---|---|---|
| M1 | quitar la fuente de respaldo (`fallbacks` vacío en `theme.tres` y en `UiTheme.make_font`) | **fallan** los 2 tests de P1: "U+25BC (▼) usado en floating_text.gd no está en la fuente del tema" (y ▲, ⚠, →, ✓) y 5 glifos con ancho 0 |
| M2 | volver al reduce doble (`reuse_bot_reduce = false` por defecto) | **fallan** los 3 tests de P2: "por defecto la sesión reutiliza el reduce", "paso 1: un reduce por acción [2] != [1]". (La primera versión de mi test fijaba el flag explícitamente y **no** detectaba la mutación; lo corregí para usar el valor por defecto) |
| M3 | `NAME_FONT` 28 -> 18 en `player_panel.gd` | **falla** el test de 22 px con la ruta del nodo en 3, 5 y 6 jugadores |
| M4 | el botón principal vuelve al estilo del secundario | **falla** "fondo distinto" |
| M5 | separación vertical de la raíz de la mesa 8 -> 0 | **fallan** las parejas "Jugar / Beber poción [16,5] < 24" (y Intercambiar, Descartar, Terminar turno) |
| M6 | la ficha muestra el coste base en vez del efectivo | **falla** `test_f_item3_...`: "Expected 'Maná: 1' to contain '2'" |

## 2. Los 12 ítems de LINEAMIENTOS §4

Veredicto contra el "hecho cuando" de cada uno, con la prueba que ejecuté. Capturas en `docs/revision/capturas/v2-35-*` (720x1280 salvo indicación).

| # | Ítem | Veredicto | Prueba (ejecutada) |
|---|---|---|---|
| 1 | Feedback de cambios | **Pasa con reserva** | Suite: `test_feedback` y mi `test_o2_feedback_one_per_event_and_survives_refresh` (1 feedback por evento, sobrevive a `refresh`, 0 refrescos por feedback). Captura `v2-35-feedback-4j-720x1280.png` (partida real con bots): números "▼ -1 maná" y "▲ +3 maná", "▼ -1" y destello sobre el panel de Ana, brillo del panel de Dario y aviso "Dario → Fire Arrow → Ana". Reserva: los números ya no tapan las cifras (QA-V2-27-01 cerrado) pero tapan el registro durante ~1 s (QA-V2-35-05); la duración >= 1 s es de la configuración del bus (lectura y test de V2-22), no la medí con cronómetro |
| 2 | Registro de 3 líneas sin claves | **Pasa** | `test_puerta_o1::test_i2_real_games_log_is_clean` y `test_log_text` (todos los `LOG_*` y los 9 `what` sin `_` ni "efecto aplicado"); capturas con 3 líneas y el nombre de los magos resaltado; mis escenarios de mesa: 0 textos con `_`. Reserva cosmética: dos líneas redundantes en la ventana de reacción (QA-V2-21-04, V2-44 no se hizo) |
| 3 | Jugables y ficha con coste efectivo | **Pasa** | Mi `test_f_item3_*`: con Fire Storm "Maná: 2 (base 1)" y "jugable == existe PLAY_CARD en `Game.legal_actions`"; mutación M6 lo detecta. Captura `v2-35-ficha-3j-720x1280.png`: jugables con marco verde claro, el resto sin marco; ficha con nombre completo, maná, tipo y elemento, resumen en español, "Ver" y pista; el motivo ("Ice Bolt cuesta 2 de maná y tienes 1. Bebe una poción.") sale una vez |
| 4 | Pago explícito | **Pasa** | Mi `test_f_item4_*`: "Fireball: paga 1 carta de fuego (1/1)" con Confirmar activo cuando hay una combinación; "(0/1)" con Confirmar inactivo cuando hay dos. Captura `v2-35-pago-3j-720x1280.png` (dos Fire Arrow resaltados, Confirmar gris). Reserva fuera del pago de hechizos: "Descarta 2 carta(s)" (QA-V2-35-02) |
| 5 | Cartas legibles / "Ver" / zoom | **Pasa con reserva** | Mi `test_f_item5_*`: botón "Ver" >= 96 visible con la carta seleccionada, un toque abre el zoom, la pista "Mantén pulsada una carta para verla" sale la primera vez. Capturas `v2-35-ficha-3j-720x1280.png` y `v2-35-zoom-3j-720x1280.png` (carta grande con su resumen bajo ella). Reserva: con 6 jugadores y la ficha abierta la mano queda diminuta (QA-V2-35-06). La pulsación larga con el dedo no se puede ejecutar aquí |
| 6 | Interfaz honesta | **Pasa con reserva** | Captura de menú (`v2-35-menu-720x1280.png`: Jugar local, Ajustes, Cómo se juega; sin Crear sala ni Unirse) y de Ajustes (`v2-35-ajustes-720x1280.png`: sin Música ni Efectos); mi test recorre 5 pantallas y 8 mesas: 0 botones sin conexión. **Reserva:** "Vibración: sí" es una opción muerta (QA-V2-35-03) |
| 7 | Preferencia de reacción | **Pasa** | Suite (`test_reaction_pref`, `test_local_auto_pass`, mi `test_o2_auto_pass_affecting_vs_all`). Simulación (`docs/qa/metricas-final.md` §4): modales al humano por partida **5,39 -> 2,77 (-48,6 %)** en 200 partidas y **5,76 -> 2,84 (-50,7 %)** en 50 (antes de V2-42: 6,20 -> 2,66, -57 %); máximo 26 -> 9. Ajustes muestra "Solo de hechizos que me afectan" por defecto |
| 8 | Pantalla de fin con resumen | **Pasa** | Capturas `v2-35-fin-6j-720x1280.png` y `v2-35-fin-3j-1080x1920.png` (partidas reales completas): título (Derrota), clasificación 1º..6º, causa y golpe final ("Se quedó sin vida - Golpe final: Bruno con Ice Boomerang"), turnos y pociones por mago, "Jugar otra vez" (violeta con borde dorado, 144 px), "Ver la mesa", "Volver al menú" separados >= 16 px. Mi `test_f_item8_*`: repetir conserva jugadores y opciones (límite 6, poción 4) con otra semilla. `test_game_over` y `test_match_summary` verdes |
| 9 | Bots sin suicidio ni acaparamiento | **Pasa** (con E6 abierta) | `metricas-final.md` §1: 200/200 terminadas, **0** Too Much Mana, 0 violaciones, **1** partida > 100 turnos (<= 4), **0** > 200, media **24,8** (<= 30), rondas en bloqueo **-91 %**; idéntico en dos corridas; semilla 1000 (22,5 de media, máx. 55) y 50 partidas sin límite de pociones (23,7; 0 bloqueos) también limpias |
| 10 | Contexto y riesgo | **Pasa** | Capturas: Beber poción ámbar con ⚠ a 8/10 (`v2-35-pociones-8-720x1280.png`, `v2-35-mesa-6j-estados-...`), "⚠ Contra ti" en la ventana de reacción (`v2-35-reaccion-6j-*`), botón de la reacción también ámbar a 8/10 (QA-V2-32-01 cerrado), "Pasa el dispositivo - Turno de Bruno" (`v2-35-pasa-dispositivo-720x1280.png`). Tests de la puerta O3 y `test_context_risk` verdes |
| 11 | "Cómo se juega" | **Pasa con reserva** | Ayuda desde el menú (`v2-35-ayuda-720x1280.png`: 8 secciones con scroll) y desde la partida (`v2-35-menu-partida-720x1280.png`: Continuar / Cómo se juega / Abandonar / Salir); tests `test_help` y los de la puerta O3 (números de la configuración, sin `_`). Reserva cosmética: texto sobre fondo con manchas (QA-V2-32-02); el contenido contra el manual lo valida el Game Designer, no lo hice |
| 12 | Legibilidad móvil | **Pasa con reservas** | Mi test: 0 textos < 22 px en 3, 5 y 6 jugadores; botones principales >= 144 (96 a 720) y secundarios >= 96 (64) con separaciones >= 16 y >= 24 junto a Beber poción, en 1080x1920 y 720x1280; iconos de estado de 48 px (`v2-35-mesa-6j-estados-720x1280.png`: nieve, ojo tachado, escudo, robot, lápida). Reservas: reacción tapa vida/maná (QA-V2-35-04), registro a 8 px de Menú (QA-V2-35-01), mano pequeña con ficha en 6j (QA-V2-35-06) |

**Veredicto por §6 de LINEAMIENTOS:** los 12 ítems cumplen su "hecho cuando" (ninguno falla, 6 con reservas menores); tests y warnings en verde; QA aporta las métricas de la sección 3. **Falta la última condición de "Aprobado": el "sí" del usuario a "¿supiste siempre qué te pasó?" en M12**, que no se puede ejecutar aquí.

## 3. Simulaciones (ejecutado; ver `docs/qa/metricas-final.md`)

Resumen: `--games 200 --seed 1` **dos veces idénticas** (texto y JSON, `cmp`); semilla 1000 (200 partidas) y 50 partidas con `--potion-limit off` limpias; mismas cifras que `metricas-base.md` (nada se movió desde V2-42). Criterios de V2-42: 1 partida > 100 turnos (<= 4), 0 > 200, media 24,8 (<= 30), 200/200, 0 eliminaciones por Too Much Mana, 0 violaciones. Las **15 cartas que nunca se juegan** y el **sesgo de asientos** (asiento 3: 58-60 de 200 con las dos semillas; 50 % con 3 jugadores) siguen igual: informativo para el Game Designer.

## 4. Rendimiento (ejecutado, `perf_table.gd`, modo `real`, 30 s, 1080x1920, 3 repeticiones, máquina libre, bajo `flock`)

| Config | Con acción p95 (3 rep.) | media | p50 | máx. | p95 todos los fotogramas (animación, sin acción) |
|---|---|---|---|---|---|
| 3j | 20,5 / 20,2 / 19,2 ms | **20,0** | 12,4 | 22,3-25,8 | 2,9 / 3,0 / 3,0 ms |
| 6j | 26,9 / 27,9 / 26,9 ms | **27,2** | 16,9 | 28,0-35,7 | 3,2 / 3,2 / 3,1 ms |

| Criterio (§2.2 de TAREAS) | Umbral | Medido | Resultado |
|---|---|---|---|
| Sin acción, con animación, p95 | <= 16 ms | 2,9-3,2 ms | **cumple** |
| Con acción, p95 | <= 57 ms | 19,2-27,9 ms | **cumple** |
| Objetivo con acción | <= 33 ms | 19,2-27,9 ms | **cumple** |
| Meta de v0.2 | <= 16 ms | 20,0 (3j) / 27,2 (6j) | **no cumple**; el informe de V2-34 documenta causa (decisión del bot 3,3 / 6,3 ms de media y hasta 20,8 ms en el 5 % peor de 6j; `refresh()` ~5 ms) y propuesta |

**Cambio frente a `docs/rendimiento/v02-final.md` (antes de P1 y P2):** 3j p95 **25,1 -> 20,0 ms (-5,1 ms, -20 %)**, p50 13,6 -> 12,4; 6j p95 **26,8 -> 27,2 ms (+0,4 ms: sin cambio, dentro del ruido de ±1-2 ms que ya documentaba V2-34)**, p50 16,7 -> 16,9. La mejora de P1 (glifo ▼▲ sin búsqueda de fuente del SO) se nota en 3j, donde las acciones del humano pesan más; P2 (un solo `reduce`, ~0,4 ms por acción de bot) no mueve el p95 de 6j, que lo fija la decisión del bot (1,96 ms de media por paso, colas de ~20 ms), tal como el propio informe de V2-34 advertía. Memoria de texturas igual (288 MB tras cargar; riesgo R19 de móvil/Web sigue). Web y Android no medidos.

## 5. Sin opciones muertas ni textos con `_` (ejecutado)

- Recorrido de menú principal, ajustes, ayuda, configuración local, "Pasa el dispositivo", mesa (8 escenarios: base, estados, Mana Focus, Elixir, maná insuficiente, descarte, reacción, 8 pociones), ficha, zoom, ventana de reacción, prompts, fin de partida y registro: **0 textos con `_`, 0 "efecto aplicado", 0 botones sin conexión** (mi test `test_f_screens_have_no_dead_buttons...` y `test_f_table_scenarios...`; más `test_puerta_o1` con 3 partidas reales y los tests de cobertura de `Strings`/`LogText`).
- **Botones que no hacen nada de verdad:** uno, **"Vibración: sí/no" de Ajustes** (QA-V2-35-03): tiene conexión (guarda un valor) pero nadie lo usa. El resto de botones de las capturas (Jugar local, Ajustes, Cómo se juega, Guardar y volver, Empezar, Atrás, Menú, Continuar, Abandonar, Salir al menú, Jugar, Intercambiar, Descartar, Terminar turno, Beber poción, Ver, Confirmar, Cancelar, Pasar, Perder 2 de vida, Comprar vida, No comprar, Ver la mesa, Volver al menú, Jugar otra vez) tiene acción real (en mis tests y capturas pulsé Jugar, Ver y el objetivo; Confirmar, Cancelar, Pasar, Beber poción y los botones de las hojas los cubren los tests de la suite, no los pulsé a mano en una ventana). No pulsé a mano "Abandonar" ni "Salir al menú" (lectura).
- Texto en inglés que sigue en pantalla: nombres de carta/evento y el texto impreso de las cartas (decisión E1(b): solo se traduce la ficha), "Elixir Transmutation" como título de diálogo. No son claves internas.

## 6. Defectos (estado final en `docs/qa/bugs.md`)

**Ninguno bloquea la aprobación.** Resumen de los que me pidió revisar el Director:

| Id | Estado final | Bloquea |
|---|---|---|
| QA-V2-27-01 (números sobre las cifras) | **Cerrado con reserva**: ya no tapan las cifras; ahora tapan el registro (QA-V2-35-05, cosmético) | no |
| QA-V2-27-02 ("Jugar otra vez" sin distinción, 14 px) | **Cerrado** (violeta + borde dorado, 144 px, >= 16 px; test y captura) | no |
| QA-V2-27-03 (abanico, marco, motivo duplicado) | **Cerrado con reserva** (nombres legibles con 5 cartas, marco claro, motivo una vez); reserva QA-V2-35-06 | no |
| QA-V2-21-05 (textos de 17 px) | **Cerrado** (0 < 22 px en 3, 5, 6 jugadores; mutación) | no |
| QA-V2-32-01 (poción en la reacción sin riesgo) | **Cerrado** (ámbar con ⚠ a 8/10) | no |
| QA-V2-32-02 (contraste de la ayuda) | **Abierto** (cosmético) | no |
| QA-V2-32-07 (orphans en tests) | **Abierto** (cosmético) | no |
| Oleada 4: descarte forzado en la barra de confirmar | Diseño distinto de la banda central; sin defecto funcional; su texto sí tiene "(s)" (QA-V2-35-02) | no |
| Oleada 4: panel propio a distinta altura con 3 y 6 | Medido: y = 769 / 851 / 935 (1080); informativo | no |
| Oleada 4: mano muy pequeña con ficha y 6 jugadores | **Confirmado** (QA-V2-35-06, menor) | no |
| Nuevos | QA-V2-35-01 (log a 8 px de Menú), 02 ("carta(s)", reabre 03-03), 03 (Vibración muerta), 04 (reacción tapa vida/maná), 05 (números sobre el registro), 06 (mano pequeña), 07 (`ARQUITECTURA.md` dice 489 líneas, hay 523), 08 (ediciones fuera de lista) | no |
| Heredados informativos | QA-V2-21-02/32-05 (partida de 140 turnos; E6), QA-V2-21-04 (log redundante; V2-44 no hecho), QA-V2-27-06 (deuda técnica) | no |

## 7. Permisos de archivos y deuda técnica

Comparado con `find ... -newer docs/historico/v0.2/puerta-o3.md` (no hay git; las comparaciones son por fecha de modificación):
- **Dentro de lista:** `player_panel`, `stat_chip`, `card_view`, `hand_view`, `table_players/center/hand/actions/mode_bar/menu/notices/dialogs` y `tests/ui/test_legibility.gd`, `capture_legibility.gd` (V2-33); `tools/perf/*` y `docs/rendimiento/v02-final.md` (V2-34); `assets/fonts/*`, `ui_theme.gd`, `theme.tres`, `test_glyph_fallback.gd` (P1); `local_session.gd`, `test_local_reduce_once.gd` (P2).
- **Fuera de la lista de V2-33 (informativo, QA-V2-35-08):** `src/ui/presentation/feedback_layer.gd`, `src/ui/card_info.gd`, `src/ui/screens/table/table_game_over.gd`, `reaction_prompt.gd` y `prompt_dialog.gd` (la fila permite `screens/*.gd` "solo tamaños"; los cambios de comportamiento de riesgo/contexto no se pueden distinguir sin historial).
- **Tests de otros editados:** `tests/qa/test_puerta_o3.gd` (mtime 20:50, posterior a mi puerta O3; contenido no verificable sin historial; sigue verde) y `tests/ui/test_theme_constants.gd` (V2-40, mtime 22:19, probablemente P1). La suite pasa y no vi aserciones debilitadas, pero no puedo demostrarlo.
- `tools/sim.gd`, `tools/test.sh`, `tools/check_warnings.sh`, `src/engine/**`, `src/ai/**`, `data/cards.json`: **sin cambios** desde la puerta O3.
- **Deuda técnica:** `table.gd` = **400 líneas** (justo en el límite; mi test de la puerta O3 lo vigila); mayor módulo de `table/`: `table_flow.gd` 246. `local_session.gd` = **523 líneas** (489 en la puerta O3; P2 añadió 34; `ARQUITECTURA.md` aún dice 489, QA-V2-35-07; la propuesta de extraer `_auto_pass_loop` y la cola de bots sigue sin hacerse). `tools/test.sh` y el candado: sin cambios; el `flock` anidado sigue siendo una trampa (la respeté: `flock` solo para Godot).
- Efecto lateral en `user://settings.cfg` (ver §1).

## 8. Lo que NO pude ejecutar

- **Móvil real, Android, Web:** ni rendimiento, ni tamaño táctil real (144 px = 48 dp es un cálculo con densidad supuesta), ni la fuente de respaldo en Web/Android (el test comprueba que la fuente tiene los glifos y que no busca fuentes del SO; no que se vea bien en un navegador), ni la memoria de texturas (R19, ~290 MB).
- **Humanos reales:** pulsación larga con el dedo, gestos, hot-seat con personas, cuántas veces interrumpe la reacción a una persona (la métrica usa un bot haciendo de humano), si un humano puede salir de un atasco (E6), duración en minutos por partida. **M12 sigue pendiente** y es la última condición de §6.
- Partida en línea (B1 no existe).
- `--randomness 15` (la corrida de la puerta O3 no se repitió; `tools/sim.gd` no la tiene y no se modifica).
- Contenido de la ayuda y de los resúmenes contra el manual (validación del Game Designer); ejecución a mano de "Abandonar" y "Salir al menú".
- Duración ≥ 1 s de cada feedback medida con cronómetro (comprobada solo por test del bus y captura).
