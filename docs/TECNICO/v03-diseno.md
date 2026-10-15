# Diseño técnico de la v0.3 (V3-02)

Autor: Lead Programmer. Fecha: 2026-10-14. Lectores: Developer (V3-11, V3-14, V3-15, V3-16, V3-20, V3-23 a V3-26), Technical Artist (V3-17, V3-30), Art (iconos), QA (V3-05, V3-18, V3-28), Producer.
Entradas: `docs/diseno/v03-ataque-defensa.md` (GD, V3-01), `docs/revision/LINEAMIENTOS-v03.md` §5-§6, `docs/revision/revision-codigo-2026-10-14.md` (A1, A3, A4, M3, M4, M5), `docs/DECISIONES.md` (E11, E12, E13, E15 pendiente), `docs/arte/descarga-v03.md`.

**Qué he visto:** `local_session.gd` completo, `game_session.gd`, `reactions.gd` (plazo y `timeout_actions`), `game.gd` (`legal_actions`, `_prompt_actions`, `resolve_spell`), `types.gd` (vistas, prompts, config), los hooks `legal_twardowskys_mirror` y `legal_magic_hand`, `action_options.gd`, `bot.gd` (`_hidden_choices`), la cáscara `table.gd` y sus módulos, `presentation_bus.gd`, `feedback_queue.gd`, `feedback_mapper.gd`, `local_setup.gd` y los tests que usan el plazo de reacción. **No he ejecutado** el juego ni los tests para este diseño.

## 0. Resumen de decisiones

| # | Decisión | Dónde |
|---|---|---|
| 1 | Los temporizadores viven **solo en `LocalSession`**, en dos colaboradores puros: `MatchClock` (cuenta con un reloj monótono inyectable) y `ClockPolicy` (lee el estado y dice qué reloj está activo y si corre). El turno no se guarda en el estado. El plazo de defensa se copia en `reaction.deadline_ms` solo para que la barra actual siga funcionando hasta V3-25 | §1 |
| 2 | Al vencer, la sesión envía **una acción nueva del motor, `TIMEOUT`**, con `scope` (`turn`, `reaction` o `prompt`) y `expect` (la decisión exacta que vence). El motor aplica E11: rechaza lo opcional, termina el turno y, solo cuando no se puede rechazar, elige al azar con el **RNG del estado**. Además escribe `LOG_TIMEOUT`, que es público | §1.5 |
| 3 | **Contrapresión** sin acoplar el motor: `GameSession.set_hold(reason, on)` (aditivo). La mesa marca `presentation` mientras el bus esté ocupado y `menu` mientras el menú esté abierto. Los bots actúan cuando se cumplen **las dos cosas**: pasó su retardo y no hay hold. Cada `FeedbackItem` lleva `hold_ms` (cuánto bloquea la secuencia) aparte de `duration_ms` (cuánto se ve) | §2 |
| 4 | **A1, opción (a):** ninguna regla de acciones legales lee información oculta. Se añaden `Types.deck_size(s)` y `Types.hand_size(s, pid)`, que funcionan sobre estado y sobre vista. Magic Hand lee `reveals[caster]`. Un test de equivalencia estado/vista recorre ≥ 1000 estados. Se retiran los parches `_add_hidden_choices` y `Bot._hidden_choices` | §3 |
| 5 | **Hot-seat oculto:** `MatchPrefs.HOT_SEAT_ENABLED = false`. Solo cambia la pantalla de nueva partida; la sesión, `TableSync` y sus tests no se tocan | §4 |
| 6 | **División de `local_session.gd`:** pasa a `BotDriver`, `ChangeTracker`, `MatchClock` y `ClockPolicy` (`RefCounted`). `GameSession` solo recibe añadidos: 1 señal, 2 métodos y 2 constantes | §5 |
| 7 | **Mesa:** V3-20 registra 5 módulos vacíos (`table_dock`, `table_banner`, `table_targeting`, `table_defense`, `table_clock`) y sus llamadas en `refresh()` y en `_build_ui()`. Excepción única: V3-20 añade 5 campos tipados a `table_context.gd` | §6 |
| 8 | **Packs:** marcos en PNG `Double` con 9-slice, filtro **lineal** (no `nearest`). Iconos sin el fondo negro, quitado una vez con un script de Art y registrado como adaptación; se tiñen con `modulate`. Cinzel como `FontVariation` (peso 600) **solo para títulos**, con DejaVu de respaldo. Las cifras del reloj van en DejaVu | §7 |

Cambios de contrato que aplica el Lead Programmer en `src/engine/types.gd` **antes** de V3-11 y V3-14 (los hago yo como paso 0; ver §9): `ACTION_TIMEOUT`, `make_action_timeout`, su entrada en `ACTION_SPECS`, `LOG_TIMEOUT`, `ERR_TIMEOUT_STALE`, las claves de config `turn_timeout_ms` y `defense_timeout_ms` (0 = sin límite) y los helpers `deck_size` y `hand_size`. Todos son aditivos: `normalize_state` rellena los valores por defecto.

---

## 1. Temporizadores en `LocalSession`

### 1.1 Principios
- El motor no lee el reloj. La sesión mide el tiempo y, al vencer, envía una acción normal (`TIMEOUT`).
- El reloj es **monótono**: `Time.get_ticks_msec()`. Se inyecta con `clock: Callable` (como hoy, pero cambia de dominio: ya no son ms unix). Los tests nunca esperan tiempo real.
- **Solo hay plazo para humanos locales.** Los bots no tienen plazo (`ClockPolicy` solo mira `local_ids`).
- **El plazo del turno no se guarda en el estado.** Las pausas (presentación, menú) son cosa del dispositivo y no son deterministas. Si fueran al estado, ensuciarían `rev` y el registro. En v0.5 (en línea), el anfitrión publicará plazos absolutos con reloj de pared, usando la misma API (§1.8).

### 1.2 Configuración (en `state.config`, aplicada por el LP en `types.gd`)
| Clave | Por defecto en el motor | Significado |
|---|---|---|
| `turn_timeout_ms` | `0` | plazo del turno completo; 0 = sin límite |
| `defense_timeout_ms` | `0` | plazo por ventana de defensa o prompt fuera de mi turno; 0 = sin límite |
| `reaction_timeout_local_ms` | `0` | **obsoleta** (v0.2). Solo se usa como plazo de defensa de las **ventanas de reacción** si `defense_timeout_ms == 0`. Así los tests de v0.2 siguen pasando |

En el motor los valores por defecto son 0 a propósito: el simulador, los tests y `Game.new_game` siguen sin reloj. Los 30 s y 20 s los pone `MatchPrefs` en la pantalla de nueva partida (V3-16; CA-TM-01). En `user://settings.cfg` las claves son `match/turn_timeout_ms` y `match/defense_timeout_ms`. Si una clave no existe, vale el defecto (30000 o 20000). `0` solo se guarda si el jugador elige "Sin límite".

### 1.3 `ClockPolicy` (`src/session/clock_policy.gd`, `RefCounted`, estático y puro)
```gdscript
## Qué reloj debe estar activo para los humanos locales y si debe correr.
## held: Dictionary de holds activos (reason -> true). No lee el reloj.
static func desired(state: Dictionary, local_ids: Array[String], held: Dictionary) -> Dictionary
## Acción TIMEOUT para lo que venció (ver §1.5). {} si ya no aplica.
static func timeout_action(state: Dictionary, d: Dictionary, kind: String) -> Dictionary
```
`desired` devuelve:
```
{ "turn":    {"key": "t:<turn.number>" | "", "pid": String, "run": bool, "why": "" | "waiting" | "defense" | "menu" | "presentation"},
  "defense": {"key": "r:<spell iid>:<stack size>" | "p:<prompt id>" | "", "pid": String, "scope": "reaction" | "prompt", "prompt_id": int,
              "run": bool, "gate": bool} }
```
Reglas. `me` es el humano local vivo. `d = Decision.decider(state)` ya prioriza los prompts, luego quien responde y luego el turno.
- **Turno activo** si `turn.current == me`, `phase == main` y `me` está vivo. Si el turno se salta (congelado), no hay `main` ni reloj (caso raro 15).
- **Defensa activa** si `d == me` y además: (a) `Reactions.current_responder == me` → `scope = reaction`, `key = r:<iid del hechizo>:<tamaño de la pila>` (cada `REACT` hace crecer la pila, así que cada ronda nueva tiene un plazo completo nuevo: CA-DF-09 y CA-VC-10); o (b) el primer prompt pendiente es de `me` y **no** es "mi turno sin reacción" → `scope = prompt`, `key = p:<id>` (T16: cada prompt tiene su plazo).
- **Un prompt propio dentro de mi turno sin reacción abierta** no activa la defensa: usa el reloj del turno (§4.3 de GD, T5).
- **Corre el turno** si está activo, `d == me`, no hay defensa activa y no hay ningún hold. Si no corre, `why` dice la causa: `waiting` (decide un bot: T4, A5), `defense` (T3), `menu` o `presentation`.
- **Corre la defensa** si está activa y no hay hold `menu`. Además tiene una **puerta de arranque** (`gate`): no empieza a contar hasta que no haya hold `presentation`, porque la hoja tiene que ser visible (D1b). Una vez arrancada, la presentación no la para (GD §4.3: "la amenaza no espera").
- `status != playing`, o `me` eliminado → nada activo (T17, CA-VC-12).

### 1.4 `MatchClock` (`src/session/match_clock.gd`, `RefCounted`, puro)
```gdscript
var turn_total_ms: int        # 0 = sin límite
var defense_total_ms: int
var reaction_only_legacy: bool  # true si viene de reaction_timeout_local_ms
func reset() -> void
## Aplica lo que pide ClockPolicy en el instante now. Devuelve true si cambió algo visible (para clock_changed).
func sync(desired: Dictionary, now: int) -> bool
## "" | "turn" | "defense": qué reloj venció y aún no se ha disparado en esta rev.
func expired(now: int, rev: int) -> String
func mark_fired(kind: String, rev: int) -> void
## ms hasta el próximo vencimiento de un reloj que corre (-1 si ninguno corre). Sirve para armar el Timer.
func next_due_ms(now: int) -> int
## Instantánea para la UI (§1.7).
func snapshot(now: int) -> Dictionary
```
Funcionamiento:
- Cada reloj guarda `key`, `left_ms` y `since` (el instante en que empezó a correr, o -1 si está en pausa).
- Pausar hace `left -= now - since` y `since = -1`.
- Reanudar el turno con `left < 1000` deja `left = 1000` (GD §4.3, CA-TM-04).
- Si la `key` cambia, el plazo empieza completo. Si la `key` del turno no cambia, el tiempo no se repone: son 30 s por turno completo (CA-TM-03). La defensa usa una `key` por ronda o por prompt.
- El plazo 0 ("Sin límite") no corre ni vence nunca (CA-TM-02).
- En modo legado, la defensa solo se activa con `scope = reaction`.

### 1.5 Qué se envía al vencer: acción `TIMEOUT` del motor

**Opciones estudiadas:**
- (A) **Acción nueva `TIMEOUT`** que resuelve el motor. **Elegida.**
- (B) La sesión elige la acción: `PASS_REACTION`, `DECLINE` y, para el azar, `Rng` sobre una copia de `state.rng_state`. **Descartada**, por cuatro motivos:
  1. No avanza el `rng_state` del estado: la elección queda correlacionada con el próximo barajado.
  2. Duplica la política E11 en la sesión, y en v0.5 también en el anfitrión.
  3. No deja en el registro público la línea "Se acabó el tiempo de X" (GD §1.2, CA-VC-01). Para eso el motor tiene que saber que fue un vencimiento.
  4. La cascada de T1, T5 y T13 serían varias acciones con estados intermedios emitidos a la mesa.

**Contrato** (lo aplica el LP en `types.gd`):
```gdscript
const ACTION_TIMEOUT: String = "TIMEOUT"   ## Solo la envía la sesión (by = "timeout"). Nunca sale en legal_actions.
const LOG_TIMEOUT: String = "timeout"      ## Público. data: {scope, resolution, prompt_kind, prompt_id}
const ERR_TIMEOUT_STALE: String = "timeout_stale"
## scope: "turn" | "reaction" | "prompt".
## expect: {"turn": int} | {"spell_iid": int, "stack": int} | {} (en prompt basta prompt_id).
static func make_action_timeout(pid: String, scope: String, prompt_id: int = -1, expect: Dictionary = {}) -> Dictionary
```
**Motor:** un archivo nuevo, `src/engine/timeout_rules.gd` (`TimeoutRules`, estático), más **una línea de despacho** en `Game.reduce`. Es determinista y no lee el reloj. Valida y luego aplica:

| scope | Válida si | Aplica (tabla de vencimientos T1-T17 de GD §5) | `resolution` |
|---|---|---|---|
| `reaction` | `current_responder == pid`, `expect` coincide con el iid del hechizo y el tamaño de la pila | `PASS_REACTION` **solo de `pid`** (hoy `timeout_actions` pasa a todos: con bots detrás eso estaría mal; CA-VC-10) | `pass` |
| `prompt` | el prompt `prompt_id` existe, es de `pid` y le toca decidir (`decider == pid`) | se resuelve el prompt (abajo) | `decline` / `zero` / `random` |
| `turn` | `turn.current == pid`, `phase == main`, `turn.number == expect.turn`, no hay reacción abierta | 1) resuelve en orden FIFO los prompts pendientes de `pid` (T5, T8-T15); 2) `END_TURN`; 3) si `END_TURN` crea prompts de `pid` (descarte por límite de mano), los resuelve (nota (4) de GD §5). Tope de 8 pasos; si `END_TURN` no es legal tras el paso 1 (otro jugador tiene que decidir), se detiene sin error | `end_turn` |

Cómo se resuelve un prompt (`TimeoutRules.resolve_prompt`). Usa `Game.legal_actions` sobre el **estado completo**, filtradas por `prompt_id`, así que la acción elegida siempre es legal:
1. Si hay `DECLINE` → `DECLINE` (T8-T12; `mana_shortfall` y `drink_or_suffer` siempre lo tienen).
2. Si el prompt es `mana_focus` sin `DECLINE` → `USE_EVENT {mana: 0}` ("no se elige nada" = gastar 0; T11). Lo valida el GD.
3. Si quedan `CHOOSE_CARDS` / `CHOOSE_TARGETS` (descarte forzado, `choose_targets`, `choose_card`) → una al azar con `Rng.next_int(state.rng_state, n)`, **avanzando** `state.rng_state` (T13-T15, E15).
4. **Nunca** `DRINK_POTION`, `USE_ARTIFACT` ni `USE_EVENT` con valor distinto de 0 (CA-VC-05). Si no queda ninguna opción → `ERR_TIMEOUT_STALE` y el estado no cambia.

`LOG_TIMEOUT` va **antes** que las entradas de lo que se aplica, que salen con normalidad: `card_discarded`, `turn_started`… El registro compone "descarta {C} al azar" con esas entradas siguientes. El robo de Magic Hand sigue siendo privado por su propia entrada.

**Si E15 se rechaza:** solo cambia el paso 3 de `TimeoutRules`. La sesión y la UI no se tocan.

### 1.6 Ciclo en `LocalSession` (sin doble disparo)
- **`_sync_clock()`** se llama al final de `_after_change`, en `set_hold` y tras cada vencimiento. Hace:
  - `desired = ClockPolicy.desired(state, _local_ids, _holds)`;
  - `MatchClock.sync`;
  - copia el plazo de defensa en `reaction.deadline_ms` mediante `Reactions.set_deadline` (compatibilidad, §1.9);
  - emite `clock_changed(snapshot)` si `sync` devolvió true;
  - re-arma un único `Timer` (`_clock_timer`, one-shot, ≥ 50 ms) con `next_due_ms`.
- **`tick(now: int = -1) -> bool`**, al vencer el `Timer`, o a mano en los tests:
  1. si `status != playing`, devuelve `false`;
  2. calcula `kind = expired(now, rev)`; si es `""`, devuelve `false`;
  3. calcula `a = ClockPolicy.timeout_action(state, desired, kind)`;
  4. llama a `mark_fired(kind, rev)` **antes** de encolar;
  5. hace `_enqueue(a, "timeout")` y devuelve `true`.
- **`check_timeouts(now)`** se mantiene como alias de `tick(now)`: los tests de v0.2 la usan.

Protección contra el doble disparo, en cuatro capas:
1. `mark_fired(kind, rev)`: como mucho un `TIMEOUT` por reloj y por `rev`.
2. `expect` en la acción: si el jugador ya actuó, o la ronda o el turno cambiaron, el motor devuelve `ERR_TIMEOUT_STALE` y no pasa nada (no se emite error a la UI: `by != "human"`).
3. Todo pasa por la misma cola `_enqueue`, que no admite reentradas: un toque y un vencimiento en el mismo fotograma se aplican en orden, y gana el primero (GD §4.5).
4. Un solo `Timer` de reloj.

`auto_clock: bool = true` (igual que `auto_run_bots`). En los tests es `false`: no se arma ningún `Timer` y se avanza con `tick(now)`.

### 1.7 API para la UI (añadidos en `GameSession`, sin romper nada)
```gdscript
const HOLD_PRESENTATION: String = "presentation"
const HOLD_MENU: String = "menu"
## Cambió el estado de los relojes: arranque, pausa, reanudación, cambio de ronda o fin.
## No se emite en cada fotograma.
signal clock_changed(clock: Dictionary)
## Instantánea calculada ahora. {} si la sesión no tiene relojes.
func get_clock() -> Dictionary: return {}
## La UI pide pausar algo. reason = HOLD_*. Una implementación sin relojes ni bots lo ignora.
func set_hold(_reason: String, _on: bool) -> void: pass
```
Formato de la instantánea (la mesa la consulta en cada fotograma desde `table_clock`, sin cálculos propios):
```
{ "turn":    {"active": bool, "pid": String, "total_ms": int, "remaining_ms": int, "running": bool, "why": String},
  "defense": {"active": bool, "pid": String, "total_ms": int, "remaining_ms": int, "running": bool, "started": bool,
              "scope": "reaction" | "prompt", "prompt_id": int, "key": String} }
```
`total_ms == 0` significa "Sin límite": se muestra la etiqueta, no la barra. Los avisos de 10 s y 5 s, el redondeo hacia arriba y `0:00` solo en el vencimiento (CA-TM-06 y CA-TM-07) son de la UI (V3-26), a partir de `remaining_ms`.

Al vencer, la mesa ve `LOG_TIMEOUT` (por el bus: banner B-TIEMPO-*) y el estado nuevo. **El borrador de la jugada (T2) lo descarta la mesa** al recibir `LOG_TIMEOUT` con `player == viewer` (V3-26 llama a `ctx.reset_flow()`). Durante 1 s tras ese `LOG_TIMEOUT`, los errores de la sesión no muestran aviso (CA-TM-10).

### 1.8 En línea (v0.5, no se hace ahora)
`ClockPolicy` y `MatchClock` sirven igual en el anfitrión con reloj de pared. El anfitrión publicará `turn.deadline_ms` y `reaction.deadline_ms` absolutos, y los clientes no enviarán `TIMEOUT`, salvo el anfitrión. Requisito anotado para reactivar el hot-seat: la defensa debe tener también una puerta de arranque "Soy X" (M3).

### 1.9 Compatibilidad y M5
- `reaction.deadline_ms` se sigue escribiendo, **en el dominio del reloj monótono**, cuando arranca o se reanuda la defensa de una reacción. Solo lo lee la barra de `reaction_prompt.gd` hasta que V3-25 y V3-26 pasen a `get_clock()`; después, en V3-39, se decide si se deja de escribir.
- Tests de v0.2 que **cambian a propósito** (regla 2 de TAREAS: los arregla quien se asigne en serie, no V3-14):
  - `tests/integration/test_local_table.gd::test_reaction_timeout_closes_modal`: con la mesa enlazada, la defensa no arranca hasta vaciar el bus. Hay que añadir `t.feedback().bus.drain()` antes de comprobar el plazo.
  - Puede pasar lo mismo en `test_puerta_o2.gd` si comprueba plazos con la mesa enlazada.
  - Los tests sin mesa (`test_local_session.gd`) no cambian.
- M5, dentro de V3-14:
  - `start()` reinicia `_queue`, `_validated`, `BotDriver`, `ChangeTracker`, `MatchClock`, `_holds`, `_bot_due` y `history`;
  - `_enqueue`: si se alcanza `MAX_QUEUE_STEPS`, hace `push_warning` con el número de acciones descartadas;
  - `history` se recorta por bloques (cuando pasa de 500 se deja en 400) para no hacer un `slice` en cada acción.

### 1.10 Tests (V3-14)
- `tests/session/test_match_clock.gd`: `MatchClock` y `ClockPolicy` puros, sin nodos. Casos:
  - 30 s por turno completo a través de varias acciones;
  - una pausa de 10 s no consume tiempo;
  - mínimo de 1 s al reanudar;
  - "Sin límite";
  - `key` nueva = plazo nuevo;
  - la puerta de arranque de la defensa;
  - el menú pausa los dos relojes;
  - la presentación no pausa una defensa ya arrancada;
  - los bots no tienen reloj;
  - un eliminado no tiene reloj.
- `tests/engine/test_timeout_action.gd`: `TIMEOUT` en el motor. Casos:
  - T1, T5 seguido de T1, T6, T7, T8-T12, T13 (misma semilla → mismas cartas; distinta → puede cambiar), T14 y T15;
  - `expect` caducado → `ERR_TIMEOUT_STALE`;
  - `TIMEOUT` nunca aparece en `legal_actions`;
  - nunca bebe;
  - `LOG_TIMEOUT` es público.
- `tests/session/test_timers_v03.gd`: con reloj inyectado y `auto_clock = false`. Cubre CA-TM-01 a 04, CA-TM-08 a 10, CA-VC-01 a 12 y el doble disparo (dos `tick` con el mismo `now` → un solo `TIMEOUT`; un toque y luego un `tick` → el `tick` sale `ERR_TIMEOUT_STALE`). Incluye las **50 partidas con un humano que nunca actúa** (bucle `run_bots` + `tick(now += total)`; 50/50 terminadas, 0 acciones de defensa o de poción del humano).

---

## 2. Secuencia de presentación (V3-15)

### 2.1 Contrapresión sin acoplar el motor
- El motor no sabe nada de esto. `LocalSession` no conoce a `PresentationBus`: solo recibe holds.
- `PresentationBus` gana `signal busy_changed(busy: bool)` y `func is_busy() -> bool`. Está **ocupado** si hay ítems pendientes, o si hay alguno activo cuyo `hold_ms` aún no ha pasado. Las etiquetas de resultado (≥ 1 s) **no** retienen: siguen viéndose mientras el siguiente actor juega (GD D3: no bloquean más de 300 ms).
- `TableFeedback.bind` conecta `bus.busy_changed` a `session.set_hold(HOLD_PRESENTATION, busy)`. En `unbind` y en `_exit_tree` lo pone a `false`.
- `LocalSession`:
  - el `_bot_timer` se arma como hoy;
  - al vencer, si hay hold `presentation` o `menu`, pone `_bot_due = true` y no actúa;
  - al soltarse el último hold, si `_bot_due`, llama a `step_bot()`.
  - Resultado: el ritmo de un bot es max(600-900 ms, presentación de la acción anterior). Un turno de 3 acciones ≈ 2,7 s (LINEAMIENTOS §6.2: ≤ 4 s).
- **Que los bots también esperen con el menú abierto** es una propuesta para que el GD la confirme: si no, la partida avanza detrás del menú y la cola se llena.
- **Vigilancia:** si el hold `presentation` dura más de `HOLD_MAX_MS = 4000` ms seguidos (con el reloj de la sesión), la sesión lo suelta, hace `push_warning` y lo apunta en `stats`. Un fallo de la UI nunca bloquea la partida. El hold `menu` no tiene tope.
- Sin mesa (simulador, tests de motor y de sesión) nadie pone holds: el comportamiento es el de hoy y las 200 simulaciones no cambian.

### 2.2 Presupuesto por acción (900 ms; 400 ms con "Reducir animaciones")
`FeedbackMapper` añade a cada ítem `hold_ms`. `duration_ms` se queda en ≥ 1000 para lo informativo.

| Ítem (kind) | Origen en el log | `hold_ms` normal / reducido |
|---|---|---|
| `card_played` (vuelo 250 + trayecto 350) | `LOG_CARD_PLAYED`, `LOG_REACTED` | 600 / 200 |
| `damage`, `heal`, `mana`, `potion` (impacto) | sus `LOG_*` | 250 / 150 |
| `label` (etiqueta de resultado) | §2.4 | 0 / 0 |
| `eliminated` | `LOG_ELIMINATED` | 500 / 300 |
| `turn` (banner B-TURNO, **nuevo**) | `LOG_TURN_STARTED` | 500 / 250 |
| `attack` (banner D0, **nuevo**) | `LOG_CARD_PLAYED` contra el que mira; lo decide la UI con `visible_to` / objetivos | 400 / 200 |
| `timeout` (B-TIEMPO-*, **nuevo**) | `LOG_TIMEOUT` | 600 / 300 |

Cadena típica: carta 600 + impacto 250 = 850 ms ≤ 900 ms. En reducido: 350 ms ≤ 400 ms.

**Retraso máximo de la cola, 1,5 s:** cada ítem guarda `queued_at` (el `now_ms` de la cola al ingerirlo). `lag_ms()` es `now_ms - queued_at` del pendiente más antiguo. Si pasa de 1500, `advance(ms)` avanza al doble (`ms * 2`) hasta bajar de 750. Se mantiene el descarte de banners viejos que ya existe (`BANNER_MAX_PENDING`). Test: 3 y 6 jugadores con bots a 0 ms de retardo durante 200 acciones, `max(lag_ms) <= 1500`.

**"Reducir animaciones":**
- `CardInfo.reduce_motion() -> bool` y `CardInfo.set_reduce_motion(bool)`, con la clave `ui/reduce_motion` en `settings.cfg` (por defecto `false`). El interruptor va en `settings.gd`.
- `TableFeedback` pasa el valor a `bus.reduced` y a `layer.reduced` al enlazar y cuando cambia el ajuste.
- `FeedbackMapper.map_entry(entry, rev, reduced)` elige la columna de `hold_ms`.
- Los efectos de V3-17 y V3-34 leen el mismo `CardInfo.reduce_motion()`. Es la única fuente.

### 2.3 Tests (V3-15)
`tests/ui/test_presentation_v03.gd`, con `auto_advance = false` y reloj inyectado:
- un bot no actúa con el bus ocupado y actúa al vaciarse;
- la vigilancia de 4 s suelta el hold;
- `lag_ms <= 1500` con 3 y 6 jugadores;
- `hold_ms` por acción ≤ 900 y, en reducido, ≤ 400;
- ningún `refresh()` por feedback (`refresh_count` sin cambios);
- el ajuste se guarda y se lee, siempre en la ruta `user://` de pruebas de V3-12.

### 2.4 Etiquetas de resultado: se deducen del log (V3-24)
Archivo nuevo: `src/ui/presentation/result_labeler.gd` (`ResultLabeler`, `RefCounted`, uno por bus). Sigue el estado de cada hechizo entre su `LOG_CARD_PLAYED` / `LOG_REACTED` (por `iid`) y su `LOG_SPELL_RESOLVED` / `LOG_SPELL_CANCELLED`, aunque lleguen en emisiones distintas.
```gdscript
func feed(entry: Dictionary, rev: int) -> Array[Dictionary]   # ítems kind = "label", extra.label = LABEL_*
```
| Entrada | Etiqueta |
|---|---|
| `LOG_DAMAGE` con `dealt > 0` y `prevented == 0` | `IMPACTO −dealt` sobre `target` (con `kind == hp_loss` también; si el `card_id` es de maná → `MANÁ −N` vía `LOG_MANA_CHANGED`) |
| `LOG_DAMAGE` con `dealt > 0` y `prevented > 0` | `REDUCIDO −dealt` |
| `LOG_DAMAGE` con `dealt == 0` y `prevented > 0` | `BLOQUEADO` |
| `LOG_REACTED` con `card_id` ∈ {Mirror Shield, Lightning} | `REFLEJADO` sobre quien reacciona. El destino recibe su propia etiqueta por su `LOG_DAMAGE` |
| `LOG_SPELL_CANCELLED` | `ANULADO` (carril `banner`/centro, sobre la carta). Ese hechizo no genera `SIN EFECTO` |
| `LOG_SPELL_RESOLVED`: cada `target` sin ninguna etiqueta desde su `card_played` | `SIN EFECTO` sobre ese mago (incluye objetivo eliminado o inmune). Si no hay `targets`, ni artefacto o evento, y nada cambió → `SIN EFECTO` sobre el lanzador |
| `LOG_HEAL` / `LOG_MANA_CHANGED` (delta ±) | `CURADO +N` / `MANÁ ±N` |
| `LOG_ELIMINATED` | `ELIMINADO` |

- Las etiquetas se apilan en el carril del panel en orden de `log_seq` (es lo que ya hace la cola).
- Los textos los da `strings_v03.gd` (V3-21). El labeler solo produce códigos `LABEL_*` y `amount`.
- Test: `tests/ui/test_result_labeler_v03.gd` con secuencias de log construidas a mano para CA-DF-10, 11 y 16 y para CA-AT-09.
- Limitación conocida: la entrada de maná de Not Enough Mana sale antes que el daño que la causa (`bus-presentacion.md` §2). No cambia la etiqueta, solo el orden.

---

## 3. Contrato de A1: acciones legales sobre la vista

### 3.1 Opción elegida: (a)
**Regla de contrato** (va a `CONTRATO-TIPOS.md` y a la cabecera de `game.gd` cuando la aplique el LP):

> `Game.legal_actions(s, pid)`, los hooks `HOOK_LEGAL_ACTIONS` y `HOOK_CAN_RESPOND`, y todo lo que llamen, **solo** pueden leer:
> - la parte pública del estado;
> - la mano propia de `pid`;
> - `reveals[pid]`.
>
> Para tamaños de zonas ocultas se usan `Types.deck_size(s)` y `Types.hand_size(s, other)`, que devuelven `deck_count` / `hand_count` en una vista y `.size()` en el estado. **No** se leen `s.deck`, `rng_state` ni la `hand` de otro jugador.

Helpers (los aplica el LP en `types.gd`):
```gdscript
static func deck_size(s: Dictionary) -> int      # bool(s.get("is_view", false)) ? int(s["deck_count"]) : s["deck"].size()
static func hand_size(s: Dictionary, pid: String) -> int
```

**Arreglos (V3-11):**
- **Twardowsky's Mirror** (`artifacts.gd`, `legal_twardowskys_mirror`): cambiar `(state["deck"] as Array).is_empty()` por `Types.deck_size(state) == 0`. El efecto (`use_twardowskys_mirror`) sigue leyendo `deck`: corre en la autoridad.
- **Magic Hand** (`support.gd`, `legal_magic_hand`): las opciones salen de la última revelación `kind == "hand"` de `from` en `reveals[caster]`. El motor ya la crea al abrir el prompt (`support.gd:71`). Así se da la misma lista sobre el estado y sobre la vista. La validación de `CHOOSE_CARDS` en `reduce` sigue comprobando contra la mano real.
- Se **retiran** `ActionOptions._add_hidden_choices` y `Bot._hidden_choices` (si el test de equivalencia pasa sin ellos). `ActionOptions.revealed_hand` se conserva como consulta.
- Cualquier otra regla que el test de equivalencia señale se arregla igual. La lista exacta la da el test, no esta tabla. Candidatos que hay que mirar: intercambiar con el mazo vacío, robos y `Reactions.legal_actions`, que solo debería leer la mano propia.

**Por qué no (b), que la autoridad calcule y envíe las acciones legales:**
- En línea habría que publicar, en cada `rev` y por jugador, listas que pueden ser enormes (combinaciones de descarte).
- `PlayFlow` y `CardInfo` exploran opciones en el cliente: seguirían necesitando `legal_actions` local.
- Añade latencia a cada toque.

(b) queda como plan B en v0.5 solo para casos concretos, si apareciera una regla que de verdad necesite información oculta para decidir si algo es legal.

### 3.2 Test de equivalencia (V3-11)
Archivo: `tests/engine/test_legal_view_equivalence.gd`.
- **Partidas:** 30 con semillas fijas, 3 a 6 jugadores, todos bots (`Bot.choose_action` con `randomness = 15` y semilla fija), igual que `tools/sim.gd`.
- **Comparación:** en cada estado alcanzado y para cada jugador vivo, `canon(Game.legal_actions(state, pid)) == canon(Game.legal_actions(Types.view_for(state, pid), pid))`. `canon` = `JSON.stringify` de cada acción con claves ordenadas, y el conjunto ordenado.
- **Tamaño:** se para en ≥ 1000 estados × jugador comparados. Hace falta cobertura mínima: ≥ 50 estados con reacción abierta, ≥ 30 con prompts pendientes y ≥ 10 con un artefacto activable en mesa. El test falla si no se llega.
- **Fixtures dirigidas** (los estados raros que la simulación casi nunca da):
  1. Mirror en mesa con el mazo lleno y el descarte vacío (el caso del bug);
  2. Mirror con el mazo vacío y el descarte vacío (no se ofrece en ninguno de los dos);
  3. prompt de Magic Hand con la mano de la víctima revelada;
  4. prompt pendiente de otro jugador (el que mira no tiene acciones);
  5. ventana de reacción donde el que mira puede beber para pagar.
- **Mensaje al fallar:** semilla, turno, `pid` y la diferencia (acciones que solo están en uno de los dos lados).
- **Tiempo:** objetivo ≤ 20 s en la suite. Si no se cumple, se baja a 15 partidas, manteniendo el mínimo de estados.

---

## 4. Ocultar el hot-seat (V3-16)
- Archivo nuevo: `src/ui/match_prefs.gd` (`MatchPrefs`, `RefCounted`, estático).
  - Constante `HOT_SEAT_ENABLED: bool = false`.
  - Lectura y escritura de `match/turn_timeout_ms` (30000), `match/defense_timeout_ms` (20000), `match/potion_limit_enabled` (**false**, decisión del usuario), `match/potion_limit` (10) y el número de bots. Usa `CardInfo.settings_path` (la misma ruta que los tests sustituyen).
  - `TURN_OPTIONS_MS = [15000, 20000, 30000, 45000, 60000, 0]` y `DEFENSE_OPTIONS_MS = [10000, 15000, 20000, 30000, 0]` (CA-TM-01).
- `local_setup.gd`, si `HOT_SEAT_ENABLED` es `false`:
  - la fila 0 es siempre "Humano" y las demás siempre "Bot"; los botones Bot/Humano se **ocultan**, no se borran;
  - el número total va de 3 a 6;
  - el stepper "Temporizador de reacción" de v0.2 se cambia por los dos selectores de tiempo;
  - `get_setup()` escribe `turn_timeout_ms`, `defense_timeout_ms` y `reaction_timeout_local_ms = 0`.

  Con `true` se comporta como en v0.2, y lo cubre un test.
- No se tocan `LocalSession`, `TableSync` ni `PassDeviceScreen`. Los tests de hot-seat crean sesiones con varios humanos directamente y siguen pasando.
- **Requisito para reactivar el hot-seat** (lo anoto en ARQUITECTURA en V3-39): puerta "Soy X" para la defensa (M3) y un reloj de turno por humano.

---

## 5. División de `local_session.gd` (V3-14, primer paso, sin cambiar el comportamiento)

Hoy tiene 523 líneas. Objetivo: `local_session.gd` ≤ 300 tras V3-14 y ≤ 340 tras V3-15. Ningún colaborador pasa de 200.

| Archivo | Clase (`RefCounted`) | Se lleva | Aprox. |
|---|---|---|---|
| `src/session/bot_driver.gd` | `BotDriver` | `_bot_ids`, `_bot_rng`, `_delay_rng`, `bot_randomness`, el tope por turno, `next_bot(state)`, `choose(state, pid, reduce_fn) -> {action, validated}`, `delay_ms(any_local_alive)`, `static safe_action(state, pid)` | 140 |
| `src/session/change_tracker.gd` | `ChangeTracker` | `_last_log_seq`, `_reaction_key`, `_seen_prompts`, `_over_emitted`; `collect(state, local_ids) -> {events, reaction, prompts, over}` (lo que hoy está en `_after_change` y `_new_log_entries`) | 90 |
| `src/session/clock_policy.gd` | `ClockPolicy` | nuevo (§1.3) | 110 |
| `src/session/match_clock.gd` | `MatchClock` | nuevo (§1.4) | 150 |

**`LocalSession` conserva:**
- el ciclo de vida del `Node` y los `Timer` (`_bot_timer`, `_clock_timer`);
- la API pública;
- `_enqueue`, `_apply`, `_reduce`, `_take_validated` y `_auto_pass_loop`;
- los holds;
- la emisión de señales.

**Nombres que deben seguir existiendo**, porque los usan tests y herramientas (como delegados finos o alias):
- de instancia: `_enqueue`, `_after_change`, `_schedule`, `_bot_action`, `_on_bot_timer`, `_bot_timer`, `_validated`, `_deadline_owner` (getter: el `pid` de la defensa activa), `check_timeouts`, `clock`, `history`, `reduce_calls`, `reuse_bot_reduce`, `bot_delay_min_ms`, `bot_delay_max_ms`, `auto_run_bots`;
- estáticos: `safe_action`, `create`, `from_setup`, `reaction_notify`, `step_bot`, `run_bots`;
- `_reaction_timer` (alias de `_clock_timer`).

**Orden de trabajo en V3-14:**
1. Partir el archivo, con los tests en verde y **sin tests nuevos**.
2. Añadir `ClockPolicy` y `MatchClock`.
3. Añadir `TIMEOUT`.
4. M5.

`GameSession` no cambia por la división. Solo recibe los añadidos de §1.7, que necesitan los temporizadores.

---

## 6. Módulos de la mesa que registra V3-20

`table.gd` está en 400 líneas. V3-20 la deja en ≤ 340 sin cambiar el comportamiento. Candidatos para sacar:
- `_refresh_log`, `_on_log_toggled` y `_log_sig` → un módulo nuevo, `table_log.gd`;
- el perfilado (`profile_refresh`, `_lap`) → ese módulo o una utilidad, manteniendo la API que usa `tools/perf`;
- los alias de compatibilidad se quedan, porque los usan los tests.

Además, V3-20 crea **5 módulos vacíos** (subclases de `TableModule`) y deja **ya escritas** en la cáscara sus llamadas de construcción y de `refresh()` (que no hacen nada). Así ninguna tarea de la oleada 2 vuelve a tocar `table.gd`.

| Módulo | Clase | Responsabilidad | Dueño | API mínima que deja V3-20 |
|---|---|---|---|---|
| `table_dock.gd` | `TableDock` | Zona de acción Z6 (Z5, el panel propio, es de `table_players`; errata C6/K4): un solo botón principal por fase, los secundarios, ocultar lo que no aplica, la fila de fichas (objetivos y respuestas) | V3-23 | `build() -> Control`, `refresh()`, `set_primary(id, text, enabled, reason)`, `show_chips(items: Array)` |
| `table_banner.gd` | `TableBanner` | Franja de banners de Z1: un solo hueco, con estilos (oro turno, carmesí ataque, plata "Puedes responder", aviso de tiempo). Lo usan defensa y reloj | V3-23 (widget); V3-25 y V3-26 lo llaman | `build() -> Control`, `show_banner(kind, title, line, style, ms)`, `clear(kind)` |
| `table_targeting.gd` | `TableTargeting` | A1-A3: válidos e inválidos a partir de `ctx.opts` (motivo del inválido calculado sobre la vista), preselección del único, marca de puntería, línea de vista previa | V3-24 | `refresh()`, `begin(iid)`, `cancel()`, `on_panel_tapped(pid) -> bool` |
| `table_defense.gd` | `TableDefense` | D0-D3: hoja "Defiéndete", consecuencia, respuestas con motivo, preselección, `Defender` / `Recibir el golpe`; prompts de un rival con la misma hoja | V3-25 | `build() -> Control`, `refresh()`, `clock_slot: Control` (hueco del anillo para V3-26) |
| `table_clock.gd` | `TableClock` | Lee `session.get_clock()` en `_process`; barra de turno, anillo de defensa (en `defense.clock_slot`), avisos de 10 s y 5 s, pausa; banners B-TURNO y B-TIEMPO-* (vía `TableBanner`); `reset_flow` al recibir un `LOG_TIMEOUT` propio; hold `menu` | V3-26 | `build() -> Control`, `refresh()` |

- **Excepción a la congelación de `table_context.gd`:** solo V3-20 añade los campos `dock`, `banner`, `targeting`, `defense` y `clock` (5 líneas tipadas) y nada más. Sin esos campos, los módulos no pueden llamarse entre sí. Después vuelve a estar congelado.
- **Orden en `refresh()`** (lo fija V3-20 y lo documenta en `division-table.md` §4.2): después de `players` y `center` van `targeting`, `defense`, `dock`, `clock`, y el último es `banner`.
- Test `tests/ui/test_table_modules_v03.gd`: los 5 módulos están en `ctx.modules`, cada uno con su campo en `ctx`; `table.gd` tiene ≤ 340 líneas; ningún módulo pasa de 400.

---

## 7. Integración de los packs (V3-30 y V3-32; iconos de Art)

**Marcos de Kenney:**
- **PNG `Double`** (piezas de 96 px), con `StyleBoxTexture` en 9-slice (márgenes = el grosor del borde de la pieza × 2), `axis_stretch_* = TILE_FIT` en los bordes y el tinte con `modulate_color` (oro `#B8913F`, lavanda, carmesí).
- Filtro **lineal**, el del proyecto. Con `stretch/mode = canvas_items` a 1080 × 1920, la escala es 1,0 en un móvil de 1080: lineal y `nearest` dan los mismos píxeles. En 720 (escala 0,667), `nearest` dejaría líneas de 1 y 2 px alternas, y lineal las suaviza de forma uniforme. Por eso `nearest` no aporta nada.
- SVG descartado: Godot lo rasteriza al importar (no hay vector en tiempo de ejecución), y el suavizado de ThorVG sobre cuadrados de 1 bit puede dejar costuras en el 9-slice.
- Si las capturas de QA a 1080 se ven borrosas, se revisa con `texture_filter = NEAREST` solo en el `PanelContainer`, nunca en contenedores con texto.

**Iconos de game-icons.net:**
- El fondo negro (`<path d="M0 0h512v512H0z"/>`) se **quita una sola vez en origen**, con un script idempotente de Art (`tools/strip_icon_bg.py`; necesita que se le asigne ese archivo). Se sobrescriben los SVG de `assets/ui_v03/game_icons/`, y en `docs/arte/licencias.md` se apunta "adaptado: se eliminó el fondo" (CC BY 3.0 lo permite indicándolo).
- Se importan como textura (`svg/scale = 0.25` → 128 px, sin mipmaps; importación del Technical Artist) y se tiñen con `self_modulate` en un `TextureRect`, porque la forma es blanca.
- Descartado:
  - un shader que convierte luminancia en alpha: un material por icono rompe el agrupado de dibujo y cuesta en Web;
  - quitar el fondo en tiempo de ejecución con `Image.load_svg_from_string`: sin caché de importación y más lento al arrancar.

**Cinzel:**
- `UiTheme.title_font() -> FontVariation`, guardada en caché: `base_font = Cinzel-VariableFont_wght.ttf`, `variation_opentype = {"wght": 600}`, `fallbacks = [DejaVuSans]`.
- Solo para títulos y banners (`add_theme_font_override`). **No** se pone como fuente por defecto del tema, así que el cuerpo sigue igual, con DejaVu de respaldo.
- Las **cifras del reloj** van en DejaVu Sans, que tiene dígitos tabulares: así "no bailan" (V3-26).
- Test `tests/ui/test_fonts_v03.gd`: la fuente de título tiene DejaVu en `fallbacks`; todas las letras de `strings_v03.gd` que van en títulos se resuelven (`has_char` en Cinzel o en DejaVu).
- Memoria: los packs suman 0,47 MB en disco. Los iconos a 128 px y los marcos `Double` están muy por debajo de los +20 MB del presupuesto. Lo mide V3-37.

---

## 8. Riesgos técnicos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Rendimiento con más animaciones (fotograma con acción p95 ≤ 27 ms + 2) | Tirones al actuar un bot | La contrapresión reparte las acciones (una cada ≥ 600 ms). Partículas `CPUParticles2D` ≤ 64 y ≤ 150 en pantalla. Ningún `refresh()` por feedback. `table_clock` solo actualiza textos cuando cambia el segundo. V3-37 mide; V3-38 se activa solo si se pasa |
| `get_clock()` y `_process` del bus en cada fotograma | Coste mínimo | La instantánea es un `Dictionary` pequeño. B6 (el bus procesa aunque esté vacío): `set_process(false)` si está inactivo, en V3-15 |
| `table.gd` en 400 líneas | Choques entre V3-23 y V3-26 | §6: V3-20 deja los 5 módulos y sus llamadas; nadie más toca la cáscara |
| Tests de reloj frágiles | Tests intermitentes | Reloj inyectado + `auto_clock = false` + `tick(now)`. Ni `await` ni `Timer` reales. `MatchClock` y `ClockPolicy` son puros y se prueban sin nodos |
| Hold `presentation` que no se suelta | Partida bloqueada | Vigilancia de 4 s (§2.1) y un test |
| Tests de v0.2 que comprueban `deadline_ms` con la mesa enlazada | Fallo esperado | Listados en §1.9; los arregla en serie quien asigne el Producer |
| `TIMEOUT` mete la política E11 en el motor | Si E15 cambia | Todo está en `TimeoutRules.resolve_prompt` paso 3 |
| `Decision` (en `src/ui/controllers`) la usan sesión y `ClockPolicy` | Dependencia de capa invertida (ya existía) | Se acepta en v0.3. Moverla a `src/session/` queda para v0.5 (anotado para V3-39) |
| El test de equivalencia es lento | Suite más larga | ≤ 20 s; si no, menos partidas, con mínimos de cobertura |

## 9. Reparto de archivos por tarea (corrige la columna "Archivos" de TAREAS)

**Paso 0, del LP, antes de V3-11 y V3-14** (propongo una fila "V3-13b"):
- `src/engine/types.gd`: `ACTION_TIMEOUT`, `make_action_timeout`, `ACTION_SPECS`, `LOG_TIMEOUT`, `ERR_TIMEOUT_STALE`, `turn_timeout_ms`, `defense_timeout_ms`, `deck_size`, `hand_size`;
- `docs/CONTRATO-TIPOS.md` y la cabecera de contrato A1.

| Id | Archivos (corregidos) | Cambio respecto a TAREAS |
|---|---|---|
| V3-11 | `src/engine/effects/artifacts.gd`, `src/engine/effects/support.gd`, `src/ui/controllers/action_options.gd`, `src/ai/bot.gd`, `tests/engine/test_legal_view_equivalence.gd` | sin cambios (necesita el paso 0) |
| V3-14 | `src/session/local_session.gd`, `src/session/game_session.gd` (añadidos de §1.7), `src/session/bot_driver.gd`, `change_tracker.gd`, `clock_policy.gd`, `match_clock.gd` (nuevos), `src/engine/timeout_rules.gd` (nuevo), `src/engine/game.gd` (solo el despacho de `ACTION_TIMEOUT`), `src/ui/components/log_text.gd` (caso `LOG_TIMEOUT`), `src/ui/strings.gd` (4 líneas de registro de GD §1.2), `tests/session/test_timers_v03.gd`, `tests/session/test_match_clock.gd`, `tests/engine/test_timeout_action.gd` | `turn_clock.gd` cambia a `match_clock.gd` + `clock_policy.gd`; se añaden la división, el motor (`timeout_rules`), `log_text` y `strings` |
| V3-15 | `src/session/local_session.gd` (`_bot_due`, vigilancia), `src/ui/presentation/presentation_bus.gd`, `feedback_queue.gd`, `feedback_mapper.gd` (`hold_ms`, kinds `turn`/`attack`/`timeout`, `queued_at`, ×2), `src/ui/presentation/feedback_layer.gd` (solo `reduced`), `src/ui/screens/table/table_feedback.gd`, `src/ui/card_info.gd`, `src/ui/screens/settings.gd`, `tests/ui/test_presentation_v03.gd` | **sale** `table_sync.gd` (no hace falta); **entran** los archivos de `presentation/` |
| V3-16 | `src/ui/match_prefs.gd` (nuevo), `src/ui/screens/local_setup.gd`, `src/ui/screens/main_menu.gd` (solo si "Partida rápida" lee `MatchPrefs`), `src/ui/ui_nav.gd` (solo si la fábrica necesita las prefs), `tests/ui/test_local_setup_v03.gd` | sin cambios; `main_menu` y `ui_nav` solo si hace falta |
| V3-20 | `src/ui/screens/table.gd`, `src/ui/screens/table/table_context.gd` (**solo** los 5 campos), `table_dock.gd`, `table_banner.gd`, `table_targeting.gd`, `table_defense.gd`, `table_clock.gd` (nuevos), `table_log.gd` (nuevo, con lo que sale de la cáscara), `docs/TECNICO/division-table.md` (orden), `tests/ui/test_table_modules_v03.gd` | +`table_banner`, +`table_log`, +excepción en `table_context` |
| V3-21 | sin cambios; además, los códigos `LABEL_*` → texto, y la tabla del efecto nominal por `card_id` (58 cartas jugables) con su test de cobertura | aclaración |
| V3-23 | `table_actions.gd`, `table_hand.gd`, `table_center.gd`, `table_mode_bar.gd`, `table_dock.gd`, `table_banner.gd`, `tests/ui/test_zones_v03.gd` | +`table_banner` |
| V3-24 | `table_targeting.gd`, `table_players.gd`, `table_feedback.gd`, `src/ui/controllers/play_flow.gd`, `src/ui/controllers/action_options.gd` (solo consultas como `targets_for(iid)`), `src/ui/presentation/result_labeler.gd` (nuevo), `presentation_bus.gd` (una llamada a `ResultLabeler.feed`), `feedback_layer.gd` (dibujo de etiquetas), `tests/ui/test_attack_flow_v03.gd`, `tests/ui/test_result_labeler_v03.gd` | +labeler, bus, capa y `action_options` |
| V3-25 | `src/ui/screens/reaction_prompt.gd`, `table_defense.gd`, `table_prompts.gd`, `table_flow.gd`, `table_notices.gd`, `src/ui/controllers/decision.gd`, `tests/ui/test_defense_flow_v03.gd` | sin cambios; **no** toca `presentation/` (usa el kind `attack` de V3-15 y `TableBanner`) |
| V3-26 | `table_clock.gd`, `src/ui/components/clock_bar.gd`, `clock_ring.gd` (nuevos), `table_menu.gd` (hold `menu` al abrir y cerrar el menú), `table_sync.gd` (silenciar el error tras `LOG_TIMEOUT`), `tests/ui/test_clock_ui_v03.gd` | +widgets, +`table_menu`, +`table_sync` |

Lotes que no chocan:
- V3-24 y V3-25 (lote 2C) no comparten archivos: el labeler es de V3-24, y V3-25 solo consume.
- V3-15 (oleada 1) y V3-24 (oleada 2) tocan `presentation_bus.gd` en oleadas distintas.

## 10. Preguntas al Game Designer (no bloquean; hay un valor por defecto)
1. Con el menú abierto, ¿también esperan los bots? Por defecto: **sí** (§2.1).
2. `mana_focus` sin `DECLINE`: al vencer se gasta 0 (§1.5, paso 2). ¿Confirmas?
3. Si `END_TURN` crea un descarte por límite de mano **dentro** del vencimiento del turno, se resuelve al azar en la misma acción (nota (4) de §5), no con un plazo nuevo (T16). ¿Confirmas?
4. E15 (azar con el RNG del estado) sigue pendiente del usuario. Está implementado de forma que solo cambia el paso 3 de `TimeoutRules`.
