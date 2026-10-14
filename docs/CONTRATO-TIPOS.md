# Contrato de tipos (T1)

La fuente de verdad es `src/engine/types.gd` (comentada clave por clave). Esto es el resumen para empezar. No edites `types.gd`: pide cambios en `docs/CAMBIOS-TIPOS.md`.

## Archivos del contrato

| Archivo | Clase | Qué es |
|---|---|---|
| `src/engine/types.gd` | `Types` | Constantes (`CARD_*`, `ACTION_*`, `ERR_*`, `STAGE_*`…), constructores `make_*`, `validate_state`, vistas, normalización JSON |
| `src/engine/rng.gd` | `Rng` | mulberry32 puro: `next(s)`, `next_int(s, n)`, `shuffle(arr, s)` → `{value/array, state}` |
| `src/engine/modifiers.gd` | `Modifiers` | Tubería de modificadores: `add`, `run_stage(s)`, `expire`, `remove_by_source` |
| `src/engine/effects/registry.gd` | `EffectRegistry` | `register(id, fn)`, `get_effect(id)`, hooks y handlers de modificadores |
| `src/engine/catalog.gd` | `CardCatalog` | Carga `data/cards.json` → `get_def(id)` |
| `src/session/game_session.gd` | `GameSession` | Interfaz local/en línea para la UI |
| `src/engine/game.gd` | `Game` | Stub con las firmas `new_game`, `reduce`, `legal_actions` (lo implementa T4) |

## Reglas del estado

- Solo tipos JSON: `int`, `String`, `bool`, `Array`, `Dictionary`. **Sin floats**, claves siempre `String`.
- Constantes como `String`, no enums `int`.
- Ids de jugador `String`; cartas físicas = instancias `{iid:int, card_id:String}`.
- `deck` y `discard`: la carta de arriba es el **último** elemento.
- `rev` +1 por acción aplicada. `rng_state` en `[0, 2^32)`.
- Tras `JSON.parse_string` o Firebase: `Types.normalize_state(raw)` (floats → int; recupera `[]`, `{}` y claves que Firebase borra; `{"0":a,"1":b}` → `[a,b]`). Para acciones: `Types.normalize_value(raw)` y luego `Types.validate_action_shape(a)`.
- Dentro del reducer, `state` es una copia de trabajo (`duplicate(true)` una vez al entrar): efectos y `Modifiers` la **mutan** y la devuelven.

Claves de primer nivel: `schema_version, rev, status, config, players, deck, discard, card_total, active_event, modifiers, pool, turn, reaction, pending, reveals, winners, seq, rng_state, log`. Jugador: `id, name, age, birth_month, is_bot, bot_level, team, hp, mana, potions, hand, artifacts, curses, flags{frozen, blinded, force_field, potent_elixir}, eliminated, eliminated_reason, turns_played, eliminated_order, eliminated_turn, eliminated_by, eliminated_card, eliminated_cause` (las seis últimas: resumen de fin, V2-06; ver «Campos del resumen de fin» abajo). Entrada de log: `type, turn, player, data, visible_to, log_seq`.

## Log numerado: `log_seq` (V2-04 / V2-14a)

- `log_seq:int` en cada entrada de `state.log`. `Types.make_log_entry` lo crea a `0` ("sin numerar"); los efectos y los `events` de `reduce` lo dejan en 0 (los `events` son copias tomadas antes de numerar: **no** llevan `log_seq` y no deben usarse para presentar). No confundir con `state.seq` (ids de prompts y modificadores).
- `Types.stamp_log_seq(entries: Array) -> int`: numera, en orden, las entradas **finales** con `log_seq <= 0` a continuación de la última numerada (o desde 1) y devuelve el último número. Incluye las que un handler `OP_CUSTOM` escribió directamente en `state.log` (p. ej. *Not Enough Mana*). `Game._append_log` la llama tras añadir los eventos de cada acción y **antes** del recorte por `config.log_limit`.
- `Types.last_log_seq(entries: Array) -> int`: mayor `log_seq` de la lista (0 si ninguna está numerada).
- Invariantes: en `state.log` los `log_seq` son > 0, estrictamente crecientes y **consecutivos** dentro de lo que queda tras el recorte (el recorte quita por el principio, así que la numeración nunca se repite ni se reinicia en la partida). No hay contador aparte: el siguiente número es `log_seq` de la última entrada + 1. Las vistas (`public_view`, `private_view`, `compose_view`) conservan `log_seq`; `compose_view` concatena público + privado, así que **no** garantiza orden cronológico: quien presenta ordena por `log_seq`.
- Estados antiguos o de Firebase sin la clave: `Types.normalize_state` la rellena con `0` (usa `make_log_entry` como plantilla). Quedan sin numerar hasta la siguiente acción: `stamp_log_seq` numera todas las entradas finales con `log_seq <= 0` (si ninguna está numerada, todo el log desde 1). Un consumidor que vea `log_seq == 0` (vista de una partida antigua) no puede deduplicar; el bus lo cuenta como `unnumbered`.
- Limitación conocida: la entrada de *Not Enough Mana* se escribe en el log antes que los `events` de la acción que la causa, así que su `log_seq` es menor que el del `LOG_DAMAGE` correspondiente.

### `state_changed(rev, events)` tras V2-14a

`events` = **entradas de log nuevas** (`log_seq` mayor que la última emitida por esa sesión), **ordenadas por `log_seq`**, **filtradas por `visible_to` para los jugadores locales** (públicas, o con algún pid local en `visible_to`). Cada entrada se emite una sola vez por sesión; la sesión avanza su marca también con las entradas filtradas. `start()` emite `[]` y toma como base `last_log_seq` del log inicial. `LocalSession` lee de `state.log` completo (`_new_log_entries`); el cliente en línea lo hará de `view.log` compuesto y normalizado. Nunca se presentan los `events` de `reduce`. Detalle: `docs/TECNICO/bus-presentacion.md` §2-§3.

## Campos del resumen de fin (por jugador, V2-06)

Aditivos, públicos, creados por `make_player` y rellenados por `normalize_state`; `SCHEMA_VERSION` no cambia; `validate_state` comprueba tipos. **Estado: aplicado y rellenado por el motor (V2-26a):** `Damage.eliminate` (`eliminated_order`, `eliminated_turn`, `eliminated_by`, `eliminated_card`, `eliminated_cause`), `_start_turn` de `game.gd` (`turns_played`) y la rama de maná insuficiente (`ELIM_CAUSE_MANA_SHORTFALL`).

| Campo | Tipo | Inicial | Significado |
|---|---|---|---|
| `turns_played` | int | 0 | nº de `turn_started` del jugador, incluidos turnos perdidos por Freeze |
| `eliminated_order` | int | 0 | 0 = vivo; si no, `rev` de la acción que lo eliminó (`state.rev + 1` mientras se aplica). Creciente; mismo valor = eliminación simultánea |
| `eliminated_turn` | int | 0 | `turn.number` de la eliminación |
| `eliminated_by` | String | "" | pid fuente del último daño/pérdida de vida que lo dejó a 0 ("" si no hay mago; siempre "" en `too_much_mana` y `concede`); puede ser él mismo |
| `eliminated_card` | String | "" | `card_id` de ese último daño ("" si no hay) |
| `eliminated_cause` | String | "" | `ELIM_CAUSE_DAMAGE` ("damage", tubería de daño), `ELIM_CAUSE_HP_LOSS` ("hp_loss", pérdida directa), `ELIM_CAUSE_MANA_SHORTFALL` ("mana_shortfall", declinó el prompt de maná insuficiente); solo con `eliminated_reason == hp`, "" en los demás |

La UI deriva el resumen de estos campos sin leer el log (`docs/TECNICO/preferencia-reaccion-y-resumen.md` §2.2). Un jugador vivo conserva los valores iniciales; los consumidores (`MatchSummary`) deben tolerarlos.

## Efecto y registro

```gdscript
# src/engine/effects/fire.gd
class_name FireEffects
extends RefCounted

static func fireball(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = (ctx["targets"] as Array)[0]
	var ev: Dictionary = Types.make_mod_event("damage", 2, ctx["caster"], target,
		Types.ELEMENT_FIRE, Types.CARD_FIREBALL, int((ctx["card"] as Dictionary)["iid"]), true)
	# Damage (T4) recorre Types.DAMAGE_STAGES con Modifiers y aplica el resultado.
	state = Damage.apply(state, ev, ctx["events"])   # firma orientativa: la fija T4
	return state
```

```gdscript
# src/engine/effects/registry.gd, en _register_all(): UNA línea por carta
	register(Types.CARD_FIREBALL, FireEffects.fireball)
```

Para abortar: `ctx["error"] = Types.ERR_INVALID_TARGET` y `return state` (el reducer descarta los cambios). Para informar: `(ctx["events"] as Array).append(Types.make_log_entry(...))`.

## Modificadores (sin dependencias cruzadas)

Un artefacto o evento solo **añade datos**; quien calcula solo **ejecuta etapas**:

```gdscript
# T6c, al equipar Wild Fire
Modifiers.add(state, Types.make_modifier("wild_fire#%d" % iid, Types.STAGE_OUTGOING, Types.OP_ADD, 1,
	caster, Types.SIDE_SOURCE, Types.ELEMENT_FIRE, Types.EXPIRES_WHILE_IN_PLAY, Types.CARD_WILD_FIRE, iid))
# T6b, al jugar Magic Shield contra el hechizo X: stage=prevent, op=sub 2, spell_iid=X, expires=spell
# T4 / Damage
ev = Modifiers.run_stages(state, Types.DAMAGE_STAGES, ev)   # outgoing → incoming → prevent → redirect
```

Etapas: `cost, outgoing, incoming, prevent, redirect, after_damage, potion, hand_limit, exchange_cost`. Operaciones: `add, sub, mul, set, prevent_all, redirect, custom` (`custom` llama a `EffectRegistry.get_modifier_handler(mod.handler)`). Caducidad: `while_in_play, next_event, owner_turn_start, end_of_turn, spell, once, never` (`once` se consume solo; el resto lo retira quien corresponda con `Modifiers.expire` o `remove_by_source`).

## Acción

```gdscript
var a: Dictionary = Types.make_action_play_card("p1", 17, ["p3"], [22])
# {"type":"PLAY_CARD","player":"p1","card":17,"targets":["p3"],"payment":[22],"target_card":-1,"extra":{}}
var r: Dictionary = Game.reduce(state, a)     # {"state":…, "error":"" | ERR_*, "events":[…]}
```

Fuera de turno solo valen `Types.OUT_OF_TURN_ACTIONS` (pociones, reacciones, prompts, Rompió la regla…). En línea la sesión añade `base_rev`.

## Vista pública / privada

| Dato | `public_view(state)` (`/public`) | `private_view(state, pid)` (`/private/{pid}`) |
|---|---|---|
| Manos | `hand: []` + `hand_count` | `hand` de pid |
| Mazo | `deck: []` + `deck_count` | — |
| `rng_state` | `0` | — |
| `reveals` | `{}` | `reveals[pid]` (Magic Hand, Twardowsky's Mirror…) |
| Log | entradas con `visible_to == []` | entradas con pid en `visible_to` |

La UI consume `Types.compose_view(pub, priv, pid)` o, en local, `Types.view_for(state, pid)`. Las vistas llevan `is_view: true`.

## Sesión (UI)

`GameSession` (Node): `submit_action(a)`, `get_view_for(pid)`, `get_local_player_ids()`, `get_rev()`, `is_authority()`. Señales: `state_changed(rev, events)`, `error(code, action)`, `reaction_opened(reaction)`, `prompt_opened(prompt)`, `game_over(winners)`. El motor no lee el reloj: la sesión fija `deadline_ms` en `reaction`/`pending` y, al vencer, envía `PASS_REACTION`/`DECLINE`.
