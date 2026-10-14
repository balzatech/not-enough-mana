# Confirmación P2 y P7 (V2-01, QA)

Tests: `tests/qa/test_repro_p2_p7.gd`. Todo lo de abajo está **verificado ejecutando** (motor real, semillas fijas); lo que sea lectura se indica.
Convención de los tests: "estado actual" pasa documentando el defecto (si se arregla, se pone rojo: señal para borrarlo); "esperado" usa `_pending_unless()` y queda `pending` hasta que el defecto se corrige, entonces pasa a verde solo.

---

## P2 - Registro

### P2.a "Icy Grasp: card_stolen_private" -> **captura antigua** (no reproducible hoy)

- Con el motor y `LogText` actuales, Icy Grasp real escribe `card_stolen` (público) y `card_stolen_private` (visible solo al lanzador y al robado). `LogText.format` da "Ana roba una carta a Bruno." y "Ana se queda <carta> de Bruno." (test `test_p2_icy_grasp_private_log_is_translated_now`).
- El texto de la captura, `"<Carta>: <clave>"`, **no lo puede producir el `LogText` actual**: su comodín es "<Carta>: efecto aplicado." Es el formato de una versión anterior (comodín `"%s: %s" % [carta, what]`). Además `partida-midgame.png` no la genera ningún script documentado (no está en `LEEME.md` ni en `tests/ui/capture.gd`), así que no hay semilla ni comando. (Las marcas de fecha de los ficheros no concuerdan con esto, pero el contenido de la imagen es decisivo; no pude regenerarla.)
- En 120 partidas bot contra bot (semillas 1-120, motor real) `card_stolen_private` salió traducido las 29 veces.
- Gravedad: ninguna hoy. Acción: regenerar `partida-midgame.png` cuando se haga V2-16.

### P2.b `LOG_MANA_CHANGED` muestra siempre "+0" -> **bug real, confirmado** (grave para la legibilidad del registro)

- Causa: `log_text.gd` lee `data.amount`; **todos** los emisores (`damage.gd` pay/lose/gain mana, `artifacts.gd:249`, `events.gd:174,273`) escriben `data.delta` (negativo al perder) y `data.target`. Además `LogText` usa `who` (= `entry.player`, es decir quien causó el efecto, a veces `""`) en vez de `data.target` (el afectado).
- Repro: `Damage.lose_mana(s, "p2", 2, events, "p1", "mana_implosion")` -> entrada `data = {target:p2, delta:-2, ...}`. Esperado "Bruno: maná -2." Real "Ana: maná +0." (y ": maná +0." si el origen es vacío). Test: `test_p2_mana_changed_shows_plus_zero_current_behaviour`.
- Frecuencia: 316 de 316 entradas `mana_changed` en 120 partidas (semillas 1-120) salieron mal (100 %).
- Arreglo (V2-16, Developer): leer `delta` (y, si `missing > 0`, opcionalmente "faltan N"), nombrar `data.target`, texto "pierde N de maná"/"gana N de maná".

### P2.c Barrido de `Types.LOG_*` y de `LOG_EFFECT.what` (escaneo en 120 partidas reales + lectura del código de los emisores)

| Clave | Estado | Detalle |
|---|---|---|
| `mana_changed` | **mal** | ver P2.b |
| `effect/blinded` (Blinding Flash) | **mal** | cae en "<Carta>: efecto aplicado." (32 veces) |
| `effect/frozen` (Freeze) | **mal** | idem; datos: `target`, `frozen` |
| `effect/frozen_bunny` | **mal** | idem (3) |
| `effect/magic_shield` | **mal** | idem (166, la más frecuente); lo emite `defensive._protect` con `what = card_id`, así también cualquier otra carta que use `_protect` |
| `effect/force_field` | **mal** | idem (27); datos: `target`, `caster` |
| `effect/mirror_shield`, `magic_capture`, `annihilation`, `lightning_redirected` | **mal (por lectura)** | emitidos en `defensive.gd:119,149,161,191` y `electric.gd:213`; `LogText` no los traduce; no aparecieron en el escaneo (o no los pude disparar); su comodín es el mismo "efecto aplicado" |
| `damage` | menor | muestra `data.amount` (daño pedido), no `data.dealt`; con `prevented > 0` o escudo dice "recibe 3" cuando recibió 0. Los emisores sí escriben `dealt` y `prevented` |
| `heal`, `potion`, `card_*`, `reaction_*`, `spell_*`, `eliminated`, `game_over`, `turn_*`, `exchange`, `deck_reshuffled`, `event_drawn`, `rule_broken` | OK | sin `_`, sin comodín, datos coherentes (`rule_broken` solo por lectura: los bots no denuncian) |
| `effect/` fizzled, used_as_payment, rule_established, peeked_*, next_potion_doubled, loss_avoided, immune, last_wish, hands_exchanged, hand_seen, hand_cards, drank_to_avoid, curse_targets, card_stolen(_detail/_private), steal_empty, lowest_mana | OK | `card_stolen_detail` solo por lectura (Magic Hand lo emite en un prompt que el bot no resuelve, ver P7) |
| `LogText.format` con tipo desconocido | menor | devuelve la clave cruda (`String(type)`); hoy ningún tipo cae ahí |

Tests: `test_p2_untranslated_effect_whats_current_behaviour` (lista fija de 9 `what` sin traducir; pasa) y `test_p2_untranslated_effect_whats_expected` (pending hasta que la lista sea vacía), `test_p2_real_games_log_defects_current_behaviour` (30 partidas).
Ningún texto con `_` aparece en partidas reales hoy (la clave `card_stolen_private` está traducida); sí hay "efecto aplicado" y "+0".

Recomendación a **V2-16 (Developer)**: (1) `mana_changed`: `delta`+`target`; (2) añadir los 9 `what` (o un comodín mejor: nombre de carta + "se activa"); (3) `damage`: usar `dealt`/`prevented`; (4) tras arreglar, borrar los tests "current_behaviour" y cambiar `_pending_unless` por `assert_true`; (5) regenerar `partida-midgame.png`.

---

## P7 - Bot que se elimina solo por Too Much Mana -> **bug real de IA, causa confirmada** (grave)

### Causa (trazada en la semilla 12, p2, turno 1, paso 8 de la partida; igual en 3, 4 y 14)

1. Alguien lanza Magic Hand sobre otro: `support.gd:magic_hand` registra en `reveals[lanzador]` la mano de la víctima y crea un prompt **no opcional** `choose_card` con `data = {from, count:1, cards:[], hidden:true}`.
2. `Bot.choose_action` trabaja con `Bot.make_view`, que **vacía las manos ajenas**. `Game.legal_actions(view)` solo obtiene las CHOOSE_CARDS de este prompt a través del hook `legal_magic_hand`, que recorre `victim["hand"]` (vacía en la vista) -> **cero CHOOSE_CARDS**. Acciones legales vistas por el bot: `[DRINK_POTION, CONCEDE]`.
3. `Bot._prompt_candidates` (rama `PROMPT_CHOOSE_CARD`) filtra `legal` por `prompt_id`: no hay candidatos -> sin `DECLINE` (el prompt no es opcional) y sin `acts` devuelve `[]`.
4. `choose_among` llama `Bot._fallback(legal)`: no hay END_TURN/PASS/DECLINE, así que devuelve `legal[0]` = `DRINK_POTION` (`prompt_id` -1, no responde al prompt).
5. El prompt sigue pendiente, `has_decision` sigue true para ese bot, y repite: beber 8 veces (potions 2->10, maná 2->26) hasta pasar el límite de 10 -> `ELIM too_much_mana`. Con `MAX_ACTIONS_PER_TURN` no se corta: ese tope solo se aplica en `_main_candidates`.

La información **sí existe**: `view.reveals[bot]` contiene la mano observada (kind `hand`, `of = from`, 5 cartas en la semilla 12). El bot simplemente no la usa (`_revealed_cards` ya sabe leerla para puntuar, pero solo se llama sobre acciones que nunca llegan a generarse).

### Reproducir
```
godot --headless --path . -s tools/sim.gd -- --games 200 --seed 1 --json /tmp/m.json   # clave tmm: semillas 3, 4, 12, 14, ...
bash tools/test.sh -gselect=test_repro_p2_p7
```
Semilla 12 (6 jugadores; `Types.make_player("p%d", ..., 18+(12*7+i*11)%50, i%12+1)`, `Game.new_game(players, {"log_limit":50}, 12)`, rng del bot `Rng.seed_from(12*31+7)`): en el paso 8 p2 tiene el prompt de Magic Hand sobre p1.
Esperado: el bot responde `CHOOSE_CARDS [iid]` con una carta de `reveals` y la roba. Real: `DRINK_POTION` en bucle y eliminación por Too Much Mana en ese mismo turno.

Tests (`tests/qa/test_repro_p2_p7.gd`): `test_p7_trace_bot_cannot_answer_hidden_magic_hand_prompt` (4 semillas: sin CHOOSE_CARDS en la vista, `legal[0]` es DRINK_POTION, el bot lo elige, reveals sí tiene la mano), `test_p7_bot_eliminates_itself_by_too_much_mana_current_behaviour` (bucle hasta la eliminación), `test_p7_bot_expected_answers_prompt_with_choose_cards` (**pending hasta V2-17**; pasa a verde sin tocarlo cuando el bot conteste y además comprueba que `Game.reduce` acepta la acción).

### ¿Afecta a un humano? No (verificado)
`ActionOptions._add_hidden_choices` completa las CHOOSE_CARDS desde `reveals`. Test `test_p7_human_can_resolve_hidden_prompt_via_reveals`: en las 4 semillas, con `Types.view_for(state, jugador)`, la UI ofrece cartas y `Game.reduce` acepta la primera y resuelve el prompt. Matiz (por lectura, no probado en pantalla): el prompt es no opcional y un humano que no elija puede quedarse bloqueado si la UI no muestra el selector; no se probó la pantalla.
Afecta además a **cualquier consumidor de `Game.legal_actions` sobre una vista** que no pase por `ActionOptions` (bots en red/sesión, tests); lo mismo valdría para el humano si algún día se usara `legal_actions(view)` directamente.

### Impacto
101 de 200 partidas sim pierden un bot por esto (~50 %): sesga todas las métricas base (`docs/qa/metricas-base.md`) y en juego real un bot se elimina en cuanto **él mismo** lance Magic Hand (el prompt es de quien lanza).

### Recomendación a **V2-17 (AI Programmer)**
- Rama `PROMPT_CHOOSE_CARD` hidden: construir las acciones `CHOOSE_CARDS [iid]` desde `Bot._revealed_cards`/reveals (última mano `of == data.from`), igual que `ActionOptions`; puntuar con `BotEval.keep_value`; elegir la mejor.
- Defensa en profundidad: en `_fallback`, no devolver `legal[0]` si es `DRINK_POTION` con `prompt_id < 0` cuando hay prompt pendiente propio (o al menos si `potion_room` es falso); y un tope de acciones por prompt para que ningún prompt desconocido produzca bucles de bebida.
- Alternativa en motor (Lead/Developer): que `legal_magic_hand` use `reveals` en vez de la mano de la víctima, así `Game.legal_actions(view)` sería correcto para todos. No es necesario si V2-17 lo resuelve en el bot.
- Tras el arreglo: la fila `too_much_mana` de `tools/sim.gd` debe ser ~0 y el test "expected" pasa a verde; borrar entonces el test `..._current_behaviour` (se pondrá rojo).
