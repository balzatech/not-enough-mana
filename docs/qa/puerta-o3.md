# Puerta de la oleada 3 (V2-32) - informe QA independiente

Fecha 2026-10-13. Godot 4.7.2, máquina libre, DISPLAY=:0 (GPU AMD Vega 10). "Ejecutado" = lo corrí yo; "lectura" = no ejecutado. Todo lo de los informes de los agentes se recomprobó, no se copió.

## Recomendación al Director

**Aprobar pasar a la oleada 4, con reservas (ninguna bloqueante).** Suite 633/633 verdes, estable en 4 ejecuciones completas (654/654 con mis 21 tests), 0 warnings, arranque del juego real sin errores en consola. Los criterios de V2-42 se cumplen y se reproducen exactamente (media 24,8; 1 partida > 100; 0 > 200; rondas en bloqueo -91 %; 200/200; 0 Too Much Mana; 0 violaciones; salida idéntica en dos corridas). Reservas, por orden:

1. **QA-V2-32-01 (menor, V2-29/V2-33):** el botón "Beber poción" del **modal de reacción** no refleja el riesgo (verde con "8/10", sin ⚠); el de la mesa sí. Mitigado: el aviso de confirmación a 10/10 sale igual (`on_drink` -> `request_drink`).
2. **QA-V2-32-04 (menor, V2-31):** el guion M12 cita cifras de los bots previos a V2-42 (9/50, 436 turnos), dice que la pantalla de fin da los "turnos y rondas" y no los da, y excede algo una página. Lo corrijo en V2-35/antes de M12 (no editado aquí).
3. **QA-V2-32-05 (informativo, V2-42):** queda 1 partida de 140 turnos (g=19, el mismo caso de 436) y con `randomness` 15 el bloqueo reaparece (38 partidas, 2 > 100): un humano **puede** seguir atascado; E6 sigue abierta. Además los bots curan un 74 % menos y el sesgo de asientos no cambia.
4. Cosméticos: contraste del texto de la ayuda sobre el fondo (QA-V2-32-02), resumen de Warp Discharge sin el caso de empate (QA-V2-32-03), orphans de tests (QA-V2-32-07).
5. Heredados abiertos de la puerta O2 que **no** se corrigieron (V2-33 los cubre): QA-V2-27-01, 02, 03, 04, 06; y QA-V2-21-05 (17 px), QA-V2-03-04 y 05. **Cerrado por casualidad: QA-V2-27-05** (test con `autofree`).

Lo que **no** pude ejecutar: móvil real, Web, Android, humanos reales (pulsación larga en ventana real, gestos, hot-seat con personas), partida online; no medí rendimiento en esta puerta (no cambió el motor ni la mesa). Ver §8.

## 1. Batería (ejecutado)

| Comando | Resultado |
|---|---|
| `bash tools/test.sh` (corrida 1) | 51 scripts, **633/633**, 11 079 asserts, 156 s |
| `bash tools/test.sh` (corrida 2) | 51 scripts, **633/633**, 11 079 asserts, 157 s; lista de tests idéntica a la corrida 1 |
| `bash tools/test.sh` con `tests/qa/test_puerta_o3.gd` (corridas 3 y 4) | 52 scripts, **654/654**, 11 975 asserts, 164-165 s |
| `bash tools/check_warnings.sh` | OK: sin warnings (la primera vez detectó 2 divisiones enteras en mi test; corregidas) |
| Arranque real `godot --path . --quit-after 240` | sin errores ni warnings en consola |

**Estabilidad:** 4 ejecuciones completas, 0 fallos. El fallo intermitente de 1 test que vio otro agente **no se reprodujo**; no puedo darle nombre. Conviene vigilarlo (los tests con partidas de bots son deterministas; el candidato más probable es un test de UI con temporizador/`await`, pero es una hipótesis sin evidencia).

**Orphans (informativo, QA-V2-32-07):** el resumen de GUT atribuye 1 orphan a `tests/ui/test_game_over.gd` (un `MainMenu` sin liberar) y las salidas por test de `test_payment_text.gd` y `test_ui_scenes.gd` listan decenas o cientos de nodos huérfanos; no hay historial git para saber si son anteriores. El orphan de `LocalSession` de la puerta O2 (QA-V2-27-05) **ya no aparece**: `test_default_mode_is_all` ahora hace `autofree(ls)`.

**P7 y la semilla 10 (ejecutado, mutación real en copia del proyecto):** `tests/qa/test_repro_p2_p7.gd` ahora usa `TMM_SEEDS = [10, 4, 12, 14]`. Con el código actual pasan. En una **copia del proyecto** del scratchpad anulé `Bot._hidden_choices` (que construye `CHOOSE_CARDS` desde `reveals`; es la corrección de V2-17): `test_p7_trace_bot_cannot_answer_hidden_magic_hand_prompt` falla ya en la primera semilla (10) con "Invalid access ... 'type'" porque el bot no devuelve acción (las aserciones previas, que exigen llegar al prompt oculto con `data.cards` vacío y que `legal[0]` sea `DRINK_POTION`, pasan para la semilla 10) y `test_p7_bot_expected_answers_prompt_with_choose_cards` (semilla 12) falla con el mensaje de V2-17. Es decir: **la semilla nueva llega de verdad al prompt oculto y los tests P7 siguen protegiendo el caso**. Salvedad: `test_p7_human_can_resolve...` no depende del bot y pasa con y sin la mutación (es correcto: protege a la UI). Edición fuera de lista: `tests/qa/test_repro_p2_p7.gd` es de QA y lo tocó la tarea V2-42 (cuya lista es `tests/ai/**`); el cambio es legítimo y no debilita nada.

## 2. V2-28 resúmenes en la ficha y el zoom - **Pasa con reservas**

Ejecutado:
- `data/card_summaries_es.json`: **61 entradas** = las 61 ids del catálogo (ni una más, ni una menos); 0 con `_`; 0 vacías; máx. **93** caracteres (`lightning_storm`; `fire_storm` e `ice_storm` 91; el resto menos de 90); todas terminan en punto; sin espacios dobles (`test_o3_summaries_cover_exactly_the_catalog`).
- `.gitignore` contiene la línea exacta y `git check-ignore -v` la confirma.
- Los textos de Lightning y Last Wish coinciden **literalmente** con los corregidos en `docs/diseno/validacion-resumenes.md`.
- **Sin el archivo** (copia del proyecto con el JSON renombrado): `test_card_summaries` da 2 verdes y 4 pending ("sin archivo"), 0 errores; captura de la ficha de Lightning a 720x1280 sin resumen: ficha normal, sin línea vacía, sin error (`caps/nofile-ficha.png`). La ficha con resumen muestra "Maná: 2 / Tipo / resumen / Mantén pulsada..." (`sum-720-ficha.png`).
- **Zoom (Read, 720x1280 y 1080x1920):** el resumen sale **debajo de la carta**, encima de "Toca para cerrar"; no tapa nombre, coste ni texto de la carta. Caso más largo (Lightning Storm, 93 car.) a 720: ocupa 2 líneas con la palabra suelta "más." pero no choca con nada.
- `test_o3_summary_in_info_matches_file_for_every_card`: la ficha muestra el resumen de cada una de las 61 cartas.

**Muestreo de 10 resúmenes contra `src/engine/effects/*.gd`** (lectura del código; la corrección de Lightning y Last Wish ya viene validada por V2-12 y la repasé):

| # | Carta | Resumen | Efecto real | Veredicto |
|---|---|---|---|---|
| 1 | Lightning | "El objetivo pierde 2 de vida; si responde con otro Lightning, +1 de daño y se redirige." | `lightning`: `LIGHTNING_DAMAGE` 2 + `LIGHTNING_CHAIN_BONUS` 1 por eslabón, la respuesta no hace daño y transmite objetivo y bono al inferior (`_chain_into_parent`), `lightning_redirected` | Correcto |
| 2 | Last Wish | "Defensiva: si un hechizo de otro mago te mata, él recibe ese mismo daño. Mueres igual." | `mod_last_wish`: solo `is_spell`, atacante distinto del dueño, dueño eliminado por `ELIM_HP`, una vez (`used`), devuelve `amount` al atacante | Correcto (un Armageddon propio no lo activa) |
| 3 | Vampiric Touch | "pierde 2 y tú ganas 1, aunque el daño se prevenga." | `VAMPIRIC_DAMAGE` 2, `Damage.heal(caster, 1)` incondicional tras `hit` (solo hace fizzle si el objetivo ya murió) | Correcto |
| 4 | Meteor Shower | "pierde 2 y sus vecinos de mesa pierden 1." | `METEOR_TARGET_DAMAGE` 2 + `METEOR_NEIGHBOR_DAMAGE` 1 a `Types.neighbors(target)` (el lanzador si es vecino) | Correcto |
| 5 | Force Field | "inmune a hechizos hasta tu próximo turno; no bloquea defensivas." | `flags.force_field = caster`; `immune()` solo para `is_spell`; `game.gd` lo borra al empezar el turno del lanzador | Correcto |
| 6 | Mana Focus | "Evento: hasta el próximo evento, puedes pagar el daño recibido con maná en vez de vida." | `mana_focus` (prioridad 1000) aplaza el daño y abre `PROMPT_MANA_FOCUS`; paga k de maná y recibe `damage - k`; solo con maná; `PERSISTENT` en `cards.json` | Correcto (admite pago parcial, ver V2-12) |
| 7 | Curse of the Elder | "Los magos mayores que tú pierden 3 de maná." | `_drain` con `age > age del lanzador` (estricto, lanzador excluido), `CURSE_MANA_LOSS` 3 | Correcto |
| 8 | Warp Discharge | "Evento: el mago con menos maná pierde 1 de vida; los demás ganan 1." | `warp_discharge`: **todos los empatados** en el mínimo pierden 1 (daño sin elemento), el resto cura 1 | **Impreciso con empates** (singular "el mago"); V2-12 lo aceptó como omisión. QA-V2-32-03, menor |
| 9 | Elixir Transmutation | "Evento: cada mago puede comprar vida a 2 de maná por punto, una sola vez." | `ELIXIR_PRICE` 2; un prompt por mago vivo con vida < máx; `USE_EVENT {amount}` hasta `min(hueco, maná/2)` | Correcto (solo magos con vida < 10 reciben la oferta; no es una pérdida de información) |
| 10 | Fireproof Tiara (artefacto) | "Artefacto: los hechizos de fuego te hacen 1 de daño menos." | `_protection(ELEMENT_FIRE)`: `STAGE_INCOMING`, `OP_SUB 1`, `spell_only` | Correcto |
| 11 | Tesla Coil (artefacto, extra) | "tus hechizos eléctricos hacen 1 de daño más." | `_bonus(ELEMENT_ELECTRIC)`: `OP_ADD 1`, lado fuente, `spell_only` | Correcto |

Resultado del muestreo: **10 correctos, 1 impreciso (Warp Discharge)**; ningún desajuste con el motor.

Reservas de V2-28: (a) el JSON no versionado (M19) significa que un clon limpio y cualquier CI no tienen resúmenes (los tests quedan `pending`, correcto, pero **hay que incluirlo en la exportación**: no lo comprobé, no hay presets de exportación probados); (b) Warp Discharge (QA-V2-32-03); (c) el zoom del Storm de 93 caracteres parte en 2 líneas (cosmético). Edición fuera de lista: `tests/ui/capture_summaries.gd` (herramienta de captura, no test).

## 3. V2-29 ítem 10 - **Pasa con reservas**

Ejecutado (Read de capturas a 720x1280 y 1080x1920 + mis tests):
- **Botón de poción de la mesa:** 7/10 verde sin símbolo; **8/10 ámbar con ⚠**; **9/10 naranja con ⚠**; **10/10 rojo con ⚠**, siempre con el contador "n/10" y un `tooltip` de aviso solo desde 8. Alto del botón idéntico con 0, 8 y 10 pociones (no cambia el tamaño). Con límite 6 (mis tests): 3/6 sin aviso, 4/6 ámbar, 5/6 naranja, 6/6 rojo, cuatro colores distintos entre sí. Sin límite (`potion_limit_enabled` false) no hay riesgo. `test_o3_potion_button_levels_with_custom_limit_and_symbol`, `..._height_does_not_change_with_risk`, `..._potion_warning_text_levels`. **Mutación:** `limit - 2` -> `limit - 3` en una copia: mi test falla.
- **"Contra ti" / "No va contra ti":** diez casos con la tabla `ReactionRelevance` y el modal real (4 magos): Fireball sobre p1 sí / sobre p3 no; Armageddon sí; Electric Explosion de p2 sí, de p1 no; Meteor Shower sobre p3 (vecinos p2 y p4) no / sobre p4 sí; Ice Boomerang de p1 contra p3 sí (el lanzador también recibe) / de p2 contra p3 no; Curse of Rules sí. En todos la etiqueta es visible y coincide con `affects`. **Mutación:** sustituir `affects(...)` por `1` en `table_prompts.gd`: mi test falla.
- **"Pasa el dispositivo":** los tres motivos "Turno de Cira", "Cira: ¿respondes al hechizo?", "Cira: tienes una decisión pendiente" (captura `risk-pass-720.png`); con reacción abierta y prompt pendiente a la vez gana uno de los dos (el motor de reacciones decide); a quien no decide le sale "turno"; ningún texto lleva `_`.

Reservas: **QA-V2-32-01** el botón de poción del **modal de reacción** (`reaction_prompt.gd`, `UiUtil.button` con estilo fijo verde) no usa `potion_risk`: a 8/10 sigue verde sin ⚠ (`risk-against-720.png`, `risk-against-1080.png`). El riesgo se ve en la mesa pero no en el sitio donde más se bebe en apuro. La confirmación a 10/10 sí existe. El modal sigue tapando el panel propio (QA-V2-03-04, V2-33).

## 4. V2-30 ítem 11 - **Pasa con reservas**

Ejecutado:
- **8 secciones en orden:** Objetivo, Tu turno, Pagar cartas y maná, Pociones de maná, Too Much Mana, Defensivas y reacciones, Eventos, Artefactos y maldiciones (`test_o3_help_eight_sections_order_and_config_numbers`; capturas Read a 720 y 1080).
- **Números de la configuración activa:** con `{start_hp 8, start_mana 2, start_hand 4, potion_mana 5, potion_limit 7}` salen "8 de vida", "+5 de maná", "7 pociones", "poción número 8", "5/7" y "7/7", y **no** quedan "+3", "10 pociones" ni el valor por defecto; con `potion_limit_enabled` false dice "no hay límite" y no habla de la poción número N. **Mutación:** fijar `+3` en `strings_ayuda.gd`: mi test falla.
- **Desde el menú principal:** botón "Cómo se juega" (>= `BUTTON_MIN_H`), `UiNav.HELP` carga `help_screen.tscn` como `HelpScreen` con 8 títulos y 8 cuerpos; Volver -> menú principal. **Desde la partida:** `table_menu.open_help()` (superposición): con una **ventana de reacción abierta** y límite 12, tras abrir y Volver la vista de la mesa es idéntica (`==` profundo) y la ventana de reacción sigue visible (`test_o3_help_from_game_with_open_reaction_keeps_state_and_reaction`). El texto de la partida usa su configuración (la captura de la partida dice "En esta partida no hay límite de pociones").
- **Aviso de evento:** el catálogo tiene **7 persistentes** (not_enough_mana, shot_glass, fire/ice/lightning_storm, mana_focus, disrupted_gravity) y **4 instantáneos** (visit_of_the_archmage, blessing, warp_discharge, elixir_transmutation) y coincide con lo que el motor hace (lectura de `events.gd`: los 7 registran modificadores `EXPIRES_NEXT_EVENT`; los 4 actúan al robarse y no dejan modificador). Textos: "Evento: X. Dura hasta el próximo evento." y "Evento: X. Efecto inmediato, no dura." (`test_o3_event_catalog_has_7_persistent_and_4_instant_and_notice_matches`; captura del zoom de un Storm).
- Textos sin `_` en 3 configuraciones; scroll vertical sin horizontal; fuentes: cuerpo 26 px, títulos 36 (>= 22).

Reservas: **QA-V2-32-02 (cosmético/menor)** el texto blanco se apoya directamente en el fondo con colores y manchas, sin panel oscuro: contraste irregular en las zonas rojas y azules a 720x1280 (legible, cansa en una pantalla de 4 secciones largas). Edición fuera de lista: `src/ui/ui_nav.gd` (constante `HELP` y navegación; imprescindible, no figura en la fila de V2-30) y `help_screen.tscn` (escena que exige la tarea).

## 5. V2-42 bots - **Pasa** (medido por QA)

Comando: `godot --headless --path . -s tools/sim.gd -- --games 200 --seed 1 --json ...`, 2 veces: **texto y JSON idénticos (`cmp`)**.

| Criterio de V2-42 | Umbral | Medido | Resultado |
|---|---|---|---|
| Partidas > 100 turnos | <= 4 (hoy 14) | **1** (g=19, 140 turnos) | cumple |
| Partidas > 200 turnos | 0 (hoy 6) | **0** | cumple |
| Media de turnos de jugador | <= 30 (hoy 39,6) | **24,8** (mediana 24; min 9; max 140) | cumple |
| Rondas en bloqueo | -50 % o más | 120 frente a 1 400: **-91 %** (13/200 partidas con bloqueo, antes 33) | cumple |
| Terminadas | 200/200 | **200/200**, 0 topadas | cumple |
| Eliminaciones por Too Much Mana | 0 | **0** | cumple |
| Violaciones / errores | 0 / 0 | **0 / 0** | cumple |
| `test.sh` | >= 465 | 633 (654 con los míos) | cumple |

Otras corridas (ejecutado; detalle en `docs/qa/metricas-base.md`): semilla **1000**, 200 partidas: media 22,5, max 55, 0 > 100, 7 con bloqueo (33 rondas), 0 TMM, 0 violaciones, 200/200. **50 partidas `--potion-limit off`:** media 23,7, max 41, 0 con bloqueo, 0 TMM, 0 violaciones. Informativas: límite 10 (50 partidas) 3 con bloqueo y max 140; límite 15: 0 y max 47; `randomness` 15 (copia de `sim.gd` del scratchpad, `tools/sim.gd` no tiene la opción): media 31,4, **2 > 100**, 38 partidas con bloqueo (281 rondas), 0 TMM, 0 violaciones.

Mis tests (`test_o3_bot_games_*`): 10 partidas de 3-6 magos con `validate_state` tras **cada** paso, `card_total` constante, vida 0-10, maná >= 0, 0 TMM y 10/10 terminadas; 4 partidas sin límite de pociones. Todas verdes.

Reservas (QA-V2-32-05, informativo): (1) sigue habiendo un caso de 140 turnos con 1 vivo a 10/10 pociones y 0 de maná (48 rondas en bloqueo): la situación **sigue siendo posible**, solo es rara; E6 no se cierra con V2-42. (2) Los bots **curan -74 %** (`heal` 443 -> 114, `greater_heal` 187 -> 43), cambio de comportamiento deliberado (reserva de pociones) pero visible para un humano. (3) El reparto por asiento sigue sesgado (60/200 al asiento 3; 3j: 50 % al asiento 3). (4) Las 15 cartas nunca jugadas son las mismas. (5) Con `randomness` 15 la mejora se erosiona. `tools/sim.gd` no se modificó.

## 6. V2-45 icono y V2-31 guion

**V2-45 - Pasa (ejecutado).** `icon_eliminado_96.png` (96x96) e `icon_eliminado_48.png` (48x48): RGBA, alfa real (0-255), contenido (ni vacío ni bloque lleno), con su `.import`; `test_o3_eliminado_icon_sizes_alpha_and_distinct_from_the_other_six`: diferencia media por píxel > 0,03 frente a cada uno de los otros 6 en ambos tamaños. **Contact sheet (Read):** lápida gris con cruz sobre base de tierra, silueta de arco distinta de la calavera morada de Maldito, del escudo, del copo, del ojo, del círculo de turno y de la cabeza de robot (que es de un gris azulado parecido pero con antena y cuadrada). Está en `tools/gen_ui_icons.py` (`"eliminado":eliminado`) y documentado en `docs/arte/iconos-estado.md`. **Idempotencia:** regeneré todo el set en una copia del proyecto y los 16 PNG de `assets/ui` son **byte a byte idénticos** a los del proyecto (los otros iconos tienen la fecha de hoy porque el generador reescribe todo, pero no cambiaron); no se tocó ninguna imagen de carta (`find assets -newer` solo da `assets/ui`). Aún no está integrado en `player_panel` (lo hace V2-33).

**V2-31 - Pasa con reservas (lectura + `wc`).** El guion (`docs/qa/guion-m12.md`, 57 líneas, 607 palabras) tiene preparación, partidas A, B y C opcional, qué anotar (minutos, turnos, rondas, segundos por turno, interrupciones por reacción, confusos, aburrimiento, tramos sin acciones, "¿pulsaste algún botón sin querer...?" con dispositivo y pantalla), plantilla con las 4 preguntas y una de decisión sobre E6, y qué hacer si algo falla. Las cifras que cita (9 de 50 con bloqueo y máx. 436 con límite 10; 1 de 50 y máx. 52 con 15; 0 de 50 desactivado) **coinciden** con `docs/diseno/opciones-bloqueo-pociones.md` (comprobado en `test_o3_guion_is_one_page_and_figures_match_the_options_doc`). Lo que **corregiría** (sin editarlo, tengo permiso solo para listarlo):
1. **Cifras desactualizadas tras V2-42:** con los bots nuevos, límite 10: **3 de 50** con bloqueo y máx. **140**; límite 15: **0 de 50** y máx. **47**; desactivado: 0 de 50, máx. 41 (ver `metricas-base.md`). La tabla de la opción (b) del documento del Game Designer tiene el mismo problema (lo mide con bots previos y dice "repetir tras V2-42").
2. **"Nº de turnos y de rondas (los da la pantalla de fin)" es falso:** la pantalla de fin da turnos y pociones **por mago** (`Strings.end_stats`), no el total ni las rondas. Decir: "suma los turnos de la pantalla de fin; las rondas son los turnos del que más ha jugado".
3. **Una página:** son 57 líneas y 607 palabras (imprimible en ~1,3 páginas); quitar la sección 5 o comprimir la 3.
4. **Comando de arranque:** `godot --path .` supone `godot` en el PATH; en esta máquina es `/home/brayan/.local/bin/godot`.
5. Pregunta 3 ("contra mí"): hoy basta con la etiqueta "Contra ti" del modal; está bien, pero conviene decir que con "solo los que me afectan" el recuento total será menor.
6. Añadir el límite de pociones usado en la partida a la plantilla (hoy solo se pregunta al final).

## 7. Permisos de archivos y límites (comparado con `find -newer docs/qa/puerta-o2.md`)

| Tarea | Fuera de su lista | Valoración |
|---|---|---|
| V2-28 | `tests/ui/capture_summaries.gd` (herramienta de captura) | menor, sin efecto |
| V2-29 | `tests/ui/capture_context_risk.gd` (captura) | menor |
| V2-30 | **`src/ui/ui_nav.gd`** (constante `HELP`), `help_screen.tscn`, `tests/ui/capture_help.gd` | `ui_nav.gd` es de V2-25c/26c: necesario para la navegación, pero no figura en la fila ni en la regla 9 de cadenas; hay que dejarlo anotado |
| V2-42 | `tests/qa/test_repro_p2_p7.gd` (semilla 3 -> 10) | legítimo y verificado (§1); es un fichero de QA |
| otros | `tests/session/test_local_auto_pass.gd` (el `autofree` de QA-V2-27-05) | arreglo benigno de un test de V2-25b, sin autor identificable |
| V2-45 | los 14 PNG de iconos y los 2 marcos reescritos por el generador | idénticos byte a byte (§6) |
| V2-31 | ninguna | ok |

`src/engine/**` y `data/cards.json` **no** cambiaron (ningún fichero de `src/engine` ni `data/` salvo `card_summaries_es.json` es más reciente que la puerta O2). **`table.gd` = 400 líneas** (<= 400, justo en el límite; mi `test_o3_table_gd_not_over_400_lines` lo vigila junto con todos los módulos de `table/`: el mayor `table_flow.gd` 246). `table_context.gd` y `table_dialogs.gd` no se tocaron (regla 3). `local_session.gd` sigue en 489 líneas (QA-V2-27-06).

## 8. Estado de los defectos abiertos y qué no se ejecutó

| Id | Estado tras la oleada 3 |
|---|---|
| QA-V2-27-01 (números flotantes) | **Abierto** (no cambió `FeedbackLayer`/`player_panel`; mtime anterior a la puerta O2; no recapturé) |
| QA-V2-27-02 ("Jugar otra vez") | **Abierto** (`game_over_summary.gd` y tema sin cambios) |
| QA-V2-27-03 (abanico, marco, motivo duplicado) | **Abierto** (`hand_view`/`card_view` sin cambios) |
| QA-V2-27-04 (`ARQUITECTURA.md` obsoleto) | **Abierto** (`grep`: líneas 89, 120 y 138 siguen con "pendiente de implementar") |
| QA-V2-27-05 (orphan de `LocalSession`) | **Cerrado** (`autofree`; el orphan ya no sale; queda uno nuevo en `test_game_over`, QA-V2-32-07) |
| QA-V2-27-06 (`local_session.gd` 489 líneas; flock anidado) | **Abierto/informativo.** Reapareció en esta puerta: quedó un proceso `flock 9` colgado de otra sesión que bloqueaba `test.sh` (lo maté). Producer debería documentar en `tools/test.sh` el uso del candado |
| QA-V2-21-02 (partidas largas) | **Mitigado por V2-42** (§5); queda informativo por el caso de 140 turnos y E6 |

**No pude ejecutar:** móvil real, Web, Android (R16), humanos reales (pulsación larga en la ventana real, toque, gestos, hot-seat con personas, minutos por partida: M12), partida online, rendimiento (no se midió en esta puerta; el motor y la mesa no cambiaron desde la puerta O2), exportación (presets), la prueba "human can't get stuck" con un humano de verdad, y el desglose por módulo de `refresh()`.

## 9. Tests propios: `tests/qa/test_puerta_o3.gd` (21 tests, ejecutados, 654/654 con la suite)

Resúmenes (cobertura exacta del catálogo, `.gitignore`, ficha sin archivo, ficha = archivo en las 61 cartas), botón de poción con límite 6 y altura constante, textos de aviso, "contra ti" con 10 hechizos y la tabla, motivos de "Pasa el dispositivo", ayuda (8 secciones, configuración, sin claves internas, desde la partida con reacción abierta, desde `UiNav`), 7+4 eventos, icono eliminado (tamaños, alfa, distinto de los demás), generador y doc, guion y cifras, límites de líneas, 10+4 partidas de bots con invariantes tras cada paso. Mutaciones comprobadas en una copia: tres cambios en `src/` (umbral del riesgo, `affects`, `+3` fijo) hacen fallar exactamente los tres tests correspondientes.
