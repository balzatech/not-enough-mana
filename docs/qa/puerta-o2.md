# Puerta de la oleada 2 (V2-27) - informe QA independiente

Fecha 2026-10-13. Godot 4.7.2, máquina libre (mediciones bajo `flock .godot/nem-godot.lock`, DISPLAY=:0, GPU AMD Vega 10). Todo lo marcado "ejecutado" lo corrí yo; "lectura" = no ejecutado. V2-44 no se hizo y no se evalúa.

## Recomendación al Director

**Aprobar pasar a la oleada 3, con reservas** (ninguna bloqueante). Suite 595/595 verdes (604/604 con mis 9 tests), 0 warnings, rendimiento de V2-22 dentro de §2.2 en 3 y 6 jugadores, la preferencia de reacciones reduce a la mitad las interrupciones al humano (-57 %), V2-39 verificado con una mutación real. Reservas a repartir, ordenadas:

1. **QA-V2-27-01 (menor, V2-22 / V2-33):** los números flotantes se dibujan encima de las cifras del panel y se apilan sin separación (con +3 maná y -2 a la vez, o en ráfagas del bot: `partida-midgame.png`), tapando vida y maná que justamente notifican.
2. **QA-V2-27-02 (menor, V2-26c):** "Jugar otra vez" es igual que los secundarios salvo el alto (la variación `ButtonPrimary` no cambia color ni borde) y la separación con "Ver la mesa" y "Volver al menú" es de 14 px a 1080 (< 16 px de §2.1).
3. **QA-V2-27-03 (menor, V2-23):** el abanico sigue cortando el nombre por solapamiento (se lee entero en la ficha); el marco de "jugable" apenas se distingue del de "no jugable" en cartas semitapadas; el motivo ("Cuesta 2 de maná y tienes 1...") sale duplicado (línea bajo el panel + ficha).
4. **QA-V2-27-04 (menor, Lead Programmer):** `ARQUITECTURA.md` quedó con "pendiente de implementar (V2-22)" y "el motor aún no los rellena (T26-A)" ya obsoletos.
5. **QA-V2-27-05 (cosmético, V2-25b):** test con nodo sin liberar: el "huérfano" del resumen de GUT es real.
6. Pendientes ya conocidos: V2-42/V2-43 (partidas largas, conclusión de V2-41 verificada), QA-V2-21-05 (17 px, V2-33).

## 1. Batería (ejecutado)

| Comando | Resultado |
|---|---|
| `bash tools/test.sh` (antes de mis tests) | 47 scripts, **595 tests, 595 pasan**, 10 434 asserts, 0 pendientes/riesgosos (las líneas con "pending" del log son nombres de tests), 177 s |
| `bash tools/test.sh` (con `tests/qa/test_puerta_o2.gd`) | 48 scripts, **604 tests, 604 pasan**, 10 792 asserts, "Orphans 1" |
| `bash tools/check_warnings.sh` | OK: sin warnings |
| Salida de Godot al cerrar | "5 ObjectDB instances leaked / 2 resources still in use" (también en los scripts de captura; ya existía, sin test fallido) |

**El "huérfano" es real.** El resumen de GUT lo atribuye a `tests/session/test_local_auto_pass.gd::test_default_mode_is_all`, que hace `assert_eq(LocalSession.new().reaction_notify, "all")` sin liberar el nodo (`Node ... (local_session.gd)`). Es un fallo del test (V2-25b), no del producto; arreglo: `autofree(LocalSession.new())`. No lo edito (test de otro).

Nota de proceso: `tools/test.sh` toma ya el candado; envolverlo en otro `flock` del mismo fichero lo bloquea para siempre (me pasó). Documentarlo en `tools/test.sh` (Producer).

## 2. Veredicto por tarea

| Tarea | Veredicto | Evidencia |
|---|---|---|
| **V2-14d** ARQUITECTURA | Pasa con reservas | `grep`: "table_context" (3), "turns_played", "incremental" presentes; solo documentación. Reserva: el texto "pendiente de implementar" de V2-22 y T26-A está obsoleto (QA-V2-27-04). Cierra QA-V2-21-03 |
| **V2-40** `BUTTON_PRIMARY_H` | Pasa | `test_theme_constants` (4) + mi `test_o2_theme_constants`: 144 >= `BUTTON_MIN_H` 96; `apply_primary` sube a 144 y no reduce un mínimo mayor (300 se queda). `tecnico.md` lista principales/secundarios y la separación 16/24. Ninguna pantalla cambia (ver §4). Edición extra: `src/ui/theme.tres` regenerado por la variación nueva (consecuencia directa) |
| **V2-22** feedback | Pasa con reservas | Mi `test_o2_feedback_one_per_event_and_survives_refresh`: 1 feedback por entrada pública de daño/curación/maná/poción (partida real de 3, semilla 5), `refresh_count` no cambia durante el feedback, un número en curso sobrevive a `refresh()`. Rendimiento §3 cumple. `table.gd` = **400 líneas** (<= 400, justo en el límite). Reserva: números sobre el texto del panel (QA-V2-27-01) |
| **V2-23** jugables + ficha | Pasa con reservas | Mi `test_o2_playable_cost_with_active_event_matches_engine`: con y sin Fire Storm, maná 0-3, 5 cartas: "jugable" == existe `PLAY_CARD` legal; coste de la ficha == `Damage.card_cost`; no jugable siempre trae motivo; Fire Storm sube Fire Arrow de 1 a 2 ("Maná: 2 (base 1)"). Captura 720x1280 con carta seleccionada y "Ver" (`v2-27-ficha-*`). Reservas QA-V2-27-03 (nombre en el abanico, marco, motivo duplicado). Cierra QA-V2-03-02 en la ficha |
| **V2-24** pago | Pasa | Mi `test_o2_payment_text_requirement_and_preselect`: "Fireball: paga 1 carta de fuego (1/1)" preseleccionado y Confirmar activo con una combinación; con dos Fire Arrow, "(0/1)" y Confirmar inactivo. `test_o2_payment_plural_and_type_requirements`: "2 cartas de ..." / "1 carta de ...", "Descarta 1 carta (Icy Grasp)." / "2 cartas", ninguna carta del catálogo produce "(s)" ni "_". Cierra QA-V2-03-03. Edición fuera de lista (conocida): `tests/ui/test_ui_scenes.gd` y `tests/integration/test_local_table.gd` por la preselección; no hay historial git para diferenciarlos, la suite sigue verde y las aserciones de `payment` siguen presentes (lectura) |
| **V2-39** huérfano | Pasa | `test_orphan_selection` (3) + mi `test_o2_orphan_selection_cleared_without_confirm_text`. **Mutación real** (copia del proyecto en el scratchpad, sin tocar `src/`): sustituí `if _drop_orphan_flow(prompts):` por `if false and ...`: `test_orphan_selection` pasa a 2/3 (falla `test_orphan_discard_is_reset`: `step` sigue en CARDS) y mi test también falla (barra de selección visible y "Confirmar"). Razón: con `prompts` vacíos solo corre la rama `prompts.is_empty()` que no toca `ctx.step`/`flow_data`. `partida-midgame.png` regenerada: sin "Descarta ... Confirmar" (se ve "Esperando a Cira..."). Cierra QA-V2-21-01 |
| **V2-25a** `ReactionRelevance` | Pasa | `test_reaction_relevance` (21 tests) verdes; tabla con entrada por carta jugable; en 200 partidas reales sin violaciones |
| **V2-25b** auto-pase | Pasa con reservas | Mi `test_o2_auto_pass_affecting_vs_all`: con `all` nunca auto-pasa y decide p1 (Magic Shield en mano); con `affecting` entre bots p2->p3 el humano se auto-pasa 1 vez (`history.by == "auto_pass"`) y no decide; si p1 es el objetivo, NO se auto-pasa; `validate_state` vacío. Métrica §5. Reserva: test con nodo sin liberar (QA-V2-27-05). Por defecto `all`: no cambia la suite |
| **V2-25c** ajustes | Pasa | `test_reaction_pref` (8); captura `v2-27-ajustes-*`: "Avisarme de reacciones" con "Solo de hechizos que me afectan", alto >= 64 a 720 (usa `BUTTON_MIN_H`). `UiNav.make_local_session` asigna `reaction_notify` desde `Settings` (lectura) |
| **V2-26a** motor | Pasa | `test_elimination_summary` (12). Mi `test_o2_engine_summary_fields_and_match_summary` (3 partidas de bots de 3-5 magos): partida terminada, `validate_state` vacío, supervivientes con `turns_played` > 0 y `eliminated_order` 0, eliminados con orden y turno > 0 sin repetidos, causa fina con `ELIM_HP`. Mismas métricas que la base corregida con 200 partidas (24,9 ventanas, 310 REACT, 8 529 pases, 14 > 100 turnos): no cambia reglas |
| **V2-26b** `MatchSummary` | Pasa | `test_match_summary` (15) + mi test: una fila por jugador, posición 1 para el ganador, ningún `_` en título, textos ni estadísticas |
| **V2-26c** fin y "Jugar otra vez" | Pasa con reservas | `test_game_over` (9). Mi `test_o2_play_again_button_is_primary_and_larger_than_secondary`: botón visible, `custom_minimum_size.y` y `size.y` >= 144 (medido: 144 px a 1080; "Ver la mesa" 105), `VARIATION_PRIMARY`, "Ver la mesa" menor que el principal y >= 96. Capturas 6j y 3j a 720x1280 y 1080x1920. Reserva QA-V2-27-02. Edición fuera de lista (conocida): `game_over_summary.gd` en `src/ui/components/` (la fila decía `src/ui/screens/`) |
| **V2-41** partidas largas | Pasa | `--games 200 --seed 1` dos veces: salida y JSON idénticos (`cmp`), 0 violaciones, 0 errores, 200/200 terminadas; mismas métricas que `metricas-base.md`. 14 > 100 turnos clasificadas (todas con bloqueo; 33/200 con algún bloqueo). Respuesta explícita: un humano **puede** quedar sin acción legal que desbloquee (solo DISCARD/END_TURN/DRINK/CONCEDE); causa necesaria la regla del límite de pociones, agravante los bots (V2-42). Lo verificado por mí es la reproducción de las cifras; la interpretación de causa queda como la deja el informe (correlación, no probada evento a evento) |

Límites de tamaño (ejecutado, `wc -l`): `table.gd` 400; el límite de 400 de `division-table.md`/`ARQUITECTURA.md` es para la mesa (`table.gd` + `table/*`, el mayor de `table/` es `table_flow.gd` con 246). Fuera de la mesa, `src/session/local_session.gd` tiene 489 líneas tras V2-25b (no está sujeto a esa regla; lo anoto por si el Lead quiere dividirlo antes de V2-30+). Ningún módulo de `table/` > 400. `table_context.gd` y `table_dialogs.gd` no se tocaron (no están en la lista de ficheros modificados desde la puerta O1).

Rutas editadas (comparado con `find -newer docs/qa/puerta-o1.md`): todo dentro de las listas de las filas, salvo (a) V2-24: dos tests antiguos; (b) V2-26c: `game_over_summary.gd` en `components/`; (c) V2-40: `theme.tres`; (d) V2-22/23: `tests/ui/capture_feedback.gd` y `capture_hand_info.gd` (herramientas de captura nuevas, no tests); (e) V2-41: `tests/qa/test_sim_bloqueo.gd` (test del sim, no en la lista); (f) `src/ui/strings_ayuda.gd.uid` (artefacto de importación). Ninguna afecta a reglas.

## 3. Rendimiento de V2-22 (ejecutado, `perf_table.gd`, 1080x1920, modo `real`, 30 s, 3 repeticiones, máquina libre)

Comando: `DISPLAY=:0 flock .godot/nem-godot.lock godot --path . -s tests/perf/perf_table.gd -- {3|6} 1080 1920 real 30`. Ms por fotograma; "activo" = fotograma con `state_changed`.

| Config | p95 todos los fotogramas (animación en curso, sin acción) | activo p95 (3 rep.) | activo p50 | activo máx | Nodos mesa |
|---|---|---|---|---|---|
| 3j | 3,6 / 3,1 / 3,3 | **29,0 / 27,3 / 27,6** (media 28,0) | 13,9 / 13,9 / 14,3 | 33,3 / 27,8 / 31,4 | 174 |
| 6j | 3,4 / 3,2 / 3,2 | **26,4 / 27,8 / 25,8** (media 26,7) | 16,4 / 15,3 / 15,5 | 33,3 / 33,3 / 36,3 | 212 |

| Criterio §2.2 | Umbral | Medido | Resultado |
|---|---|---|---|
| Fotogramas con animación, sin `state_changed`, p95 | <= 16 ms | 3,1-3,6 ms | **cumple** |
| Fotograma con acción, p95 | <= 57 ms (objetivo <= 33) | 25,8-29,0 ms | **cumple, también el objetivo** |
| Refrescos completos disparados por feedback | 0 | 0: `refresh_count` idéntico antes y después de vaciar el bus (mi test y `test_feedback`) | **cumple** (por test; `perf_table.gd` no cuenta refrescos: no lo instrumenté) |
| Desglose de `refresh()` por módulo | en el informe de V2-22 | no verificado por mí | lectura |

Contra la base `v02-base.md` (activo p95 54,8 en 3j y 56,7 en 6j; p50 38,3 y 42,2): p95 -49 % y -53 %; p50 -64 % y -63 %. Contra lo que informó V2-22 (24,5-26,3 ms en 3j y 28,5-32,9 ms en 6j): en 3j salí algo peor (25,8-29,0 vs 24,5-26,3 esperado) y en 6j algo mejor (25,8-27,8 vs 28,5-32,9); misma magnitud, diferencias de máquina/variación. Ni el máximo (hasta 36,3 ms) pasa de 57 ms. `refresh()` aislado: 0,5 ms (3j) y 1,0 ms (6j) frente a 33 y 29 ms en la base (medido por el script en estado sin cambios, lo cual es el caso incremental, no el peor). Meta de v0.2 (<= 16 ms en el fotograma con acción) no cumplida; a juzgar en V2-34.

## 4. Botones nuevos (§1.9 / §2.1)

- Ejecutado/lectura: `grep` de `UiTheme.BUTTON_MIN_H`/`BUTTON_PRIMARY_H`/`apply_primary` en el código nuevo: ficha "Ver" (`card_info.gd`: `BUTTON_MIN_H`, ancho 150), "Avisarme de reacciones" (`settings.gd`: `BUTTON_MIN_H`), "Ver la mesa", "Volver al menú", "Ver resultado" (`BUTTON_MIN_H`), "Jugar otra vez" (`BUTTON_PRIMARY_H` + `apply_primary`). Ninguno usa un literal.
- Ningún botón existente cambió de tamaño: regeneré con `capture_v02.gd` los casos `base-inicio` y `mesa-6j` a 720x1280 y 1080x1920 (`v2-27-base-inicio-*`, `v2-27-mesa-6j-*`) y medí en píxeles contra los de la puerta O1 (`v02-base-inicio-*`, `v02-mesa-6j-*`): Beber poción 112 px de alto en ambas versiones a 1080, fila Jugar/Intercambiar/Descartar/Terminar turno 90 px frente a 91 (+-1 de redondeo), mismos x. Lo que cambia es el panel del registro (ahora de 2-3 líneas), no un botón. Se confirma además comparando visualmente la cabecera (`Menú` mismo ancho).
- Separación: `Ver la mesa` / `Volver al menú` / `Jugar otra vez` a 14 px a 1080 (< 16 px): QA-V2-27-02.

## 5. Ventanas de reacción: `affecting` frente a `all` (ejecutado)

Método: `tools/sim.gd` no tiene humano, así que añadí `--reaction-notify affecting|all` (solo esa bandera y sus contadores; sin la bandera el comportamiento y la salida son idénticos: `--games 200 --seed 1` reproduce las cifras de `metricas-base.md`). El asiento p1 se trata como el humano local jugado por el bot: con `affecting`, antes de elegir actor se aplica `ReactionRelevance.auto_pass_action(state, ["p1"], "affecting")` exactamente como `LocalSession._auto_pass_loop`; se cuentan las ventanas con p1 en `awaiting` y los "modales" (decisiones de p1 en una ventana: lo que vería el humano). Comando: `godot --headless --path . -s tools/sim.gd -- --games 50 --seed 1 --reaction-notify affecting|all`.

| 50 partidas, semilla 1 | Ventanas abiertas (todas) | Ventanas con p1 en `awaiting` | Modales al humano p1 | Máx. por partida | Auto-pases |
|---|---|---|---|---|---|
| Línea base corregida (200 partidas) | **24,9** por partida (310 REACT) | n/d | n/d | 43 (ventanas) | n/d |
| Sin bandera (50 partidas) | 23,9 | n/d | n/d | 40 | n/d |
| `all` | 23,9 | 310 (6,20/partida) | **6,20** por partida | 22 | 0 |
| `affecting` | 23,9 | 310 (6,20/partida) | **2,66** por partida | 7 | 177 (3,54/partida) |

Lectura: de las ~24 ventanas por partida, un humano participa en ~6,2 (las demás son entre otros); con `affecting` se le interrumpe **2,66 veces, -57 %** (máximo 22 -> 7). Las ventanas abiertas, los REACT (70) y los turnos son idénticos entre modos: el bot-humano nunca habría reaccionado a lo que no le afectaba, así que la preferencia no cambia la partida. Salvedad: lo medido es el bot haciendo de humano (pasa el 96,5 % de las veces); un humano real con Magic Shield podría querer reaccionar a más hechizos, y `affecting` se lo quita solo cuando `affects` es falso (la política es del Game Designer). 0 violaciones, 0 errores en ambos modos.

## 6. Capturas (ejecutado, revisadas con Read; en `docs/revision/capturas/`)

`v2-27-feedback-{3j,6j}-{720x1280,1080x1920}`, `v2-27-ficha-*`, `v2-27-ficha-nojugable-{ice_bolt,magic_cap}-720x1280`, `v2-27-abanico-firestorm-6j-*`, `v2-27-pago-*`, `v2-27-ajustes-*`, `v2-27-fin-{3j,6j}-*`, `v2-27-base-inicio-*`, `v2-27-mesa-6j-*`. Generadas con un script de captura propio del scratchpad (`cap.gd`, estados con motor real; el feedback se inyecta con `FeedbackLayer.play` para forzar +3 maná y -2 a la vez).

Defectos visuales:

1. **Números flotantes sobre el panel (QA-V2-27-01), `v2-27-feedback-6j-1080x1920.png` y `partida-midgame.png`.** El "-3" de Bruno cubre su cifra de vida, el "+1" de Cira cubre su vida, y en Ana "+3 maná" queda sobre la fila de pociones y "-2" encima; no se solapan entre sí (se apilan en vertical) pero ocultan lo que anuncian. En `partida-midgame.png` (ráfaga real de bots) hay cuatro "+3 maná" y tres "-1/-2" superpuestos e ilegibles.
2. **Marco de "jugable" en el abanico (QA-V2-27-03), `v2-27-abanico-firestorm-6j-720x1280.png`.** Jugables = borde verde claro y brillo; no jugables = borde verde oscuro: en las cartas semitapadas (Magic Shield, Mirror Shield, Heal) la diferencia es casi imperceptible. En la mano de 5 con pago (`v2-27-pago-720x1280.png`) sí se distinguen. La carta seleccionada (marco amarillo) se ve bien.
3. **Motivo duplicado (QA-V2-27-03), `v2-27-ficha-nojugable-ice_bolt-720x1280.png`:** "Ice Bolt cuesta 2 de maná y tienes 1. Bebe una poción." aparece bajo el panel propio y otra vez en la ficha.
4. **Nombre cortado en el abanico (QA-V2-27-03):** "FIRE ARR", "ICE BO", "MAGIC SH", "MIRROR S" por solapamiento; la ficha lo muestra completo ("Fireball"). QA-V2-03-02 queda cerrado en la ficha, no en la mano.
5. **"Jugar otra vez" (QA-V2-27-02), `v2-27-fin-6j-720x1280.png`:** mismo color, borde y tipografía que "Ver la mesa" y "Volver al menú"; solo es más alto (144 vs 105). Separación 14 px a 1080.
6. Pantalla de fin correcta: título "Gana Cira", fila por mago ordenada, causa y golpe final ("Golpe final: Cira con Ice Boomerang"), turnos y pociones, sin claves internas; 6 filas caben a 720x1280 sin desplazamiento. Ajustes: correcto. Pago: texto con requisito, jugables resaltadas, Confirmar inactivo con dos combinaciones.
7. **QA-V2-03-06 (evento vacío):** `v2-27-mesa-6j-*` (semilla 11) reproduce la ranura "Evento" vacía con Fire Storm en el descarte: el log dice que se descartó por estar en la mano inicial; sigue siendo legítimo. En `v2-27-abanico-firestorm-6j` con Fire Storm activo la ranura "Evento" sí lo muestra. Cerrado, sin defecto.

## 7. Tests propios: `tests/qa/test_puerta_o2.gd` (9 tests, ejecutados, 358 asserts)

`test_o2_feedback_one_per_event_and_survives_refresh`, `test_o2_payment_text_requirement_and_preselect`, `test_o2_payment_plural_and_type_requirements`, `test_o2_playable_cost_with_active_event_matches_engine`, `test_o2_auto_pass_affecting_vs_all`, `test_o2_engine_summary_fields_and_match_summary`, `test_o2_play_again_button_is_primary_and_larger_than_secondary`, `test_o2_theme_constants`, `test_o2_orphan_selection_cleared_without_confirm_text`. En la copia con la mutación de V2-39 el último falla (8/9), como debe. Escritos desde los criterios (escenarios y semillas propias), no copiados de los tests de cada tarea.

## 8. No ejecutado

- Móvil real, Web, Android (R16 sigue sin medir fuera de escritorio). Tiempo real con un humano jugando.
- V2-44 (no hecho). Desglose de `refresh()` por módulo del informe de V2-22 (no lo revisé).
- Reacciones con un humano real en lugar de un bot-humano; `all`/`affecting` con hot-seat de varios humanos.
- Secuencias raras de motor (Lightning/Mirror Shield, Annihilation sobre Annihilation, Armageddon que mata a todos) no se repitieron aquí: la oleada 2 no tocó reglas y las 200 partidas dan los mismos totales que la base corregida.
