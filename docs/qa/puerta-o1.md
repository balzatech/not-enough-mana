# Puerta de la oleada 1 (V2-21) - informe QA independiente

Fecha 2026-10-13. Godot 4.7.2. Todo lo marcado "ejecutado" lo corrí yo; lo marcado "lectura" no se ejecutó.

## Recomendación al Director

**Aprobar pasar a la oleada 2, con reservas** (ninguna es bloqueante). Suite y warnings en verde, 0 `pending`, 0 eliminaciones por Too Much Mana en bots, 200/200 partidas terminadas, interfaz honesta, registro limpio. Hay que cerrar antes de la puerta de la oleada 2 (no antes de empezarla): R1-R4 de abajo.

## 1. Batería (ejecutado)

| Comando | Resultado |
|---|---|
| `bash tools/test.sh` (antes de añadir mis tests) | **457/457 pasan**, 34 scripts, 8362 asserts, 186 s. 0 fallos, 0 `pending`, 0 `risky` |
| `bash tools/test.sh` (con `tests/qa/test_puerta_o1.gd`, 8 tests nuevos) | **465/465 pasan**, 35 scripts (ver "Resultado final") |
| `bash tools/check_warnings.sh` | `OK: sin warnings` |
| `tests/qa/test_repro_p2_p7.gd` | 0 llamadas a `_pending_unless` (solo queda la definición del helper, sin usar); 0 tests `*_current_behaviour`. P2 y P7 en verde (`test_p2_mana_changed_expected_text`, `test_p2_untranslated_effect_whats_expected`, `test_p7_bot_expected_answers_prompt_with_choose_cards` con `assert_true`) |
| Juego real `godot --path .` 8 s, DISPLAY=:0 | arranca sin errores ni warnings en consola (solo mensajes de driver GL de Mesa) |
| `tests/integration/capture_local.gd` (partida local real, `midgame` y `gameover`, semilla 11) | termina con código 0, sin errores |

Nota: la suite imprime muchas líneas "Orphans" (nodos huérfanos en tests de UI). Preexistente, no falla; no lo he investigado.

## 2. Veredicto por tarea

| Tarea | Veredicto | Evidencia propia |
|---|---|---|
| V2-13 (dividir `table.gd`) | **Pasa con reservas** | 14 archivos en `src/ui/screens/table/` con los 14 nombres pedidos. Líneas: actions 136, center 67, context 244, dialogs 109, flow 246, game_over 49, hand 118, menu 78, mode_bar 160, module 16, notices 98, players 98, prompts 217, sync 93; cáscara `table.gd` 333. Ninguno > 400. Tests existentes de integración (`test_local_table.gd`, `local_ui_driver.gd`) sin modificar (mtime anterior a V2-13) y suite en verde. Reserva: la comparación pixel a pixel contra `v02-base-*` no puede aislar V2-13, porque V2-16 y V2-18 cambian la misma pantalla en la misma oleada; ver sección 3. |
| V2-14a (log_seq y eventos de sesión) | **Pasa** | `Game._append_log` llama `Types.stamp_log_seq` antes del recorte (único cambio en `game.gd`, mtime 10:41). 5 casos: `test_log_seq.gd` (2) + `test_session_events.gd` (3), verdes. |
| V2-14b (bus y cola) | **Pasa** | `feedback_mapper/queue/presentation_bus.gd` existen; `test_presentation_bus.gd` con 8 casos (incluye `test_four_player_game_one_feedback_per_entry`), verdes. `feedback_layer.gd` no existe (correcto, es V2-22). |
| V2-14c (documentación) | **Pasa con reservas** | `CONTRATO-TIPOS.md` documenta `log_seq`, `stamp_log_seq`, `last_log_seq`, `state_changed` y los 6 campos del jugador (`turns_played`, `eliminated_*`) con valor inicial y significado. `ARQUITECTURA.md` describe el bus y el contrato de `state_changed` (sección "Presentación", línea 81 y siguientes). `DECISIONES.md` tiene filas de V2-04 (línea 21), V2-05 (23) y V2-06 (25). Reserva R3: `ARQUITECTURA.md` no menciona la división de la mesa (V2-05, `src/ui/screens/table/`) ni los campos de V2-06; V2-21 pedía que recogiera V2-04 y V2-06. |
| V2-15 (interfaz honesta) | **Pasa** | Menú: solo "Jugar local" y "Ajustes" visibles y activos (test mío + capturas `v2-15-*`). Ajustes: solo Vibración e Idioma; sin Música/Efectos; `settings.gd` conserva la clave `ui/vibration` y carga el cfg existente. |
| V2-16 (registro) | **Pasa** | 3 últimas líneas con nombres resaltados en las capturas (`base-inicio`, `mesa-6j`, `base-reaccion`); sin `_` ni "efecto aplicado" en 7 tipos de entrada x 2 variantes de datos, 9 `what` y en 3 partidas reales de bots (ver sección 4). `mana_changed` con `delta` y `target` correctos. `partida-midgame.png` regenerada (ver hallazgo QA-V2-21-01). Reserva menor: líneas redundantes seguidas ("Bruno juega Ice Bolt contra Ana." y "Bruno lanza Ice Bolt contra Ana. Hora de reaccionar.", `v02-base-reaccion`). |
| V2-17 (bots) | **Pasa** | Simulación corta de 20 partidas: 20/20 terminadas, 0 eliminaciones por Too Much Mana (0 con prompt obligatorio, 0 voluntarias), 0 violaciones, 0 errores. Mi test: 16 partidas (semillas 2,3,4,5,12,13,14,15 x 3 y 6 jugadores, mitad con `randomness` 15) 16/16 terminadas, 0 Too Much Mana, invariantes OK en cada acción. `LocalSession.bot_randomness` = 15 con humanos (línea 114-115). Las 200 partidas no las repetí: `metricas-base.md` las cubre (0 TMM, 200/200) y la corrida de 20 es coherente (misma partida larga de 436 turnos). |
| V2-18 (tema) | **Pasa con reservas** | `FONT_MIN` 22, `BUTTON_MIN_H` 96, `FONT_FLOAT` 44; dos shaders solo `canvas_item`, sin `hint_screen_texture` (compatibles con Compatibility/Web). Capturas: botones más altos (Menú de 90 a ~98 px a 1080) y texto del registro legible. Reserva R4: no todo el texto cumple 22 px a 1080: etiquetas de estado de `player_panel.gd` (17), "Bot"/"TURNO" (~17-20) y el texto de las cartas (11-14, es la imagen/CardView). No comprobé el shader en Web (no hay build). |
| V2-19 (iconos) | **Pasa** | 6 iconos x (48, 96) + 2 marcos 9-slice en `assets/ui/` con `.import`; `docs/arte/iconos-estado.png` muestra copo, ojo tachado, escudo, calavera, flecha, robot; a 48 px se distinguen por silueta y color. Extra no listado: `tools/gen_ui_icons.py` y `docs/arte/iconos-estado.png` (fuera de la lista de rutas, inocuo). |
| V2-20 (rendimiento) | **Pasa con reservas** | `docs/rendimiento/v02-base.md` con p50/p95, cómo reproducir, 3 repeticiones; `tests/perf/*` nuevos, sin código de producción. Reserva R2 (informativa para la oleada 2): el fotograma con `state_changed` cuesta 38-68 ms (presupuesto 16 ms); `refresh()` 29-43 ms. Web/Android no medidos. |
| V2-37 (zoom) | **Pasa** | `CardZoom` ya se dibuja con tamaño y fondo (captura `capture_v02 zoom` sin ajuste manual: carta grande, "Toca para cerrar"). `test_card_zoom.gd` (2 tests) verdes: tamaño > 0, fondo alpha > 0.5, cierre con toque. Solo comprobado en `SubViewport`, no pulsación larga en ventana real (no hay forma de automatizarla aquí). |
| V2-38 (línea base) | **Pasa** | `metricas-base.md` (corregida) y `metricas-base-mvp-sesgada.md` existen; comando documentado; comparación fila a fila presente; 0 violaciones. No repetí las 200 partidas; mi corrida de 20 (semilla 1) coincide en la forma (partida de 436 turnos, cartas nunca jugadas, 0 TMM). |

## 3. Comparación visual `v02-base-*` (ejecutado, `capture_v02.gd` semilla 11)

Mismo tamaño y mismo contenido; diferencia medida por píxeles (umbral 8/255) y revisada con Read:

| Caso | Píxeles distintos | Qué cambia |
|---|---|---|
| base-inicio 1080 / 720 | 19,1 % / 20,1 % | Todo lo que está bajo el registro baja: el registro pasa de 1 línea (Menú 10-100 px, registro 110-194) a 3 líneas (registro 118-220, ~+18 px) y el botón Menú crece de 90 a 98 px (V2-18). Rivales +56 px, centro (mazo/descarte/evento) +42, panel de Ana +28; botones de acción, "Beber poción" y la mano en abanico **no se mueven** (misma posición). Texto del registro: "Empieza la partida. / Turno 1: Ana." con "Ana" resaltada en dorado, en lugar de "Registro: Turno 1: Ana." |
| base-reaccion | 4,2 % / 4,4 % | Solo cabecera, registro de 3 líneas con nombres resaltados y el desplazamiento de los paneles de rivales. El modal "Hechizo entrante", cartas, barra de tiempo y botones están en la misma posición. |
| base-pago | 24,9 % / 25,9 % | Mismo desplazamiento del bloque superior; el modo de pago (Fire Arrow seleccionada, "Fireball: paga con 1 carta(s) (0/1)", Confirmar/Cancelar) y la mano no cambian. |
| mesa-6j | 23,3 % / 24,4 % | Igual que base-inicio; los 5 rivales caben a 1080; a 720 los paneles siguen apretados pero legibles (QA-V2-03-05 sigue abierto). |
| zoom | 1,0 % | Solo cabecera y registro bajo el velo oscuro. |

Conclusión: los cambios visibles son los esperados (registro de 3 líneas más alto, botón de menú más alto, nombres resaltados). No encuentro otra diferencia estructural. No puedo certificar "idéntico salvo registro y tema" a nivel de píxel porque no existe una captura pre-V2-13 con el resto de cambios congelados; la identidad de comportamiento de V2-13 se apoya en la suite verde con los tests de integración sin tocar.

Mesas a 720x1280 revisadas con Read: `mesa-6j`, `base-inicio`, `base-pago`, `base-reaccion` (capture_v02) y las de 3 y 6 jugadores de `capture.gd` (estas salen con el aviso modal "Nuevo evento" encima porque el estado falso saca un evento; los paneles de rivales de 6 jugadores se ven tras el modal con "Congelado", "ELIMINADO", "DESCONECTADO" sin cortes). Sin textos cortados en los paneles ni en los botones; el nombre del jugador "Aldric" queda tapado por el modal (solo en esa captura). La mano en abanico sigue cortando los nombres de carta (QA-V2-03-02, abierto, ítem 5).

## 4. Tests nuevos independientes: `tests/qa/test_puerta_o1.gd` (8 tests, ejecutados)

- Ítem 2: `mana_changed` con `delta` (gana y pierde) nombra a `data.target` (Cira, no al lanzador Ana) y la cantidad; todos los `LOG_*` y los 9 `what` limpios (sin `_`, sin "efecto aplicado", no vacíos); `damage` bloqueado dice "bloqueado/evita" y con `dealt` 3 muestra 3; el registro muestra exactamente las 3 últimas entradas (7 entradas -> "Turno 5..7"), resalta nombres y se despliega/pliega; 3 partidas reales de bots (3, 4 y 6 jugadores, > 300 entradas del motor) sin ninguna entrada sucia.
- Ítem 6: el menú no tiene botones activos "Crear sala" ni "Unirse"; ajustes sin Música/Efectos/Sonido, con Vibración, y `settings.gd` conserva `"ui", "vibration"`.
- Ítem 9: 16 partidas de bots (3 y 6 jugadores; semillas que fallaban en la línea base 3, 4, 12, 14), mitad con `randomness` 15: todas terminan, 0 eliminaciones por Too Much Mana, `validate_state` tras cada acción.
- Errores míos durante el desarrollo de los tests (datos `to`/`from` con el tipo equivocado) no son defectos del producto: los `what` esperan cadena salvo `lightning_redirected`, que espera listas.

## 5. Otras comprobaciones

- Archivos y permisos (por fechas de modificación, no hay git): `src/engine/` solo tocó `game.gd` (V2-14a). `data/` y las imágenes de cartas no cambian. Fuera de la lista de V2-13..20 modificaron `src/ui/strings.gd`, `src/ui/strings_ayuda.gd`, `docs/narrativa/*`, `docs/diseno/*` y `docs/ESCALADOS.md` (otros agentes, no son tareas de esta puerta).
- `docs/ARQUITECTURA.md` y `docs/DECISIONES.md`: ver V2-14c.

## 6. Hallazgos nuevos (no corregidos)

- **QA-V2-21-01 (menor, por confirmar):** en `partida-midgame.png` (regenerada por V2-16) y en `capture_local.gd midgame` semilla 11, la mesa muestra "Descarta 1 carta(s) (Ice Bolt) (0/1)" y "Confirmar" mientras Ana tiene 0 cartas y el estado no tiene ningún `pending` (verificado con script: `hand 0, pending []`, turno de Cira). Es un modo de selección huérfano: `TablePrompts.update_overlays` cierra el diálogo cuando no hay prompts pero no resetea `ctx.step`/`flow_data` de un `choose_cards` abierto. En la captura el prompt lo resuelve el script por fuera de la UI, así que en juego real es poco probable (la UI lo resuelve ella misma), pero deja una captura incorrecta como evidencia del ítem 2. Responsable: Developer (V2-13/`table_prompts.gd`). Pedir regenerar la captura sin ese artefacto.
- **QA-V2-21-02 (informativo, balance/bots):** partida g=19 (semilla 20, 6 jugadores): 436 turnos y 1 477 pasos. Analizada con script: desde el turno ~49 quedan 2 jugadores vivos (p1 y p5, 1-5 de vida) más 4 eliminados; ambos con 10 pociones (el límite), 0 de maná y mano de 3-5 cartas, y no usan las pociones para pagar hechizos. En toda la partida: 39 cartas jugadas, 874 descartes, 922 robos, 35 puntos de curación y 92 de daño, 6 rebarajados. Patrón: bots que acumulan pociones sin beberlas voluntariamente (regla del límite de pociones) y descartan por límite de mano turno tras turno; las únicas jugadas son curas y poco daño. No es un fallo del motor (sin bucle ni violación) pero alarga la cola (14 partidas > 100 turnos en 200). Propuesta para el AI Programmer/Game Designer: valorar que el bot beba para jugar un ataque cuando está en la mesa con pocos rivales y mucha poción acumulada. No se ha tocado nada.
- **QA-V2-21-03 (menor):** el test `test_bot_games_with_fake_effects_no_illegal_actions_no_loops` imprime 45/50 terminadas con efectos falsos (comportamiento preexistente, el test lo tolera).
- **QA-V2-21-04 (cosmético):** registro redundante en la ventana de reacción ("juega X contra Y" y "lanza X contra Y. Hora de reaccionar.").

## Reservas a cerrar antes de la puerta de la oleada 2

- R1: regenerar `partida-midgame.png` sin el modo de selección huérfano (QA-V2-21-01) - Developer.
- R2: el fotograma de acción (38-68 ms) supera el presupuesto de 16 ms antes de añadir feedback animado: V2-22 debe resolverlo o dejar escrito el riesgo - Performance/Developer.
- R3: añadir a `ARQUITECTURA.md` la división de la mesa (V2-05) y los campos de V2-06 (o una línea que remita a `CONTRATO-TIPOS.md`) - Lead Programmer (V2-14c).
- R4: texto de 17-20 px en `player_panel.gd` vs mínimo 22 px de V2-18 - Technical Artist/Developer.

## Resultado final de la suite con mis tests

`bash tools/test.sh`: **465/465 pasan** (457 + mis 8), 35 scripts, 8555 asserts, 171 s, 0 `pending`. `bash tools/check_warnings.sh`: `OK: sin warnings` (ejecutado después de añadir mis tests).
