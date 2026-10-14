# Bus de eventos de presentación (V2-04)

Autor: Lead Programmer. Fecha: 2026-10-13. Lo implementa el Developer en **V2-14** (parte A + parte B) y lo engancha a la mesa **V2-22** (ítem 1 de LINEAMIENTOS §4).
Lectores: Developer (V2-14, V2-22), Technical Artist (V2-18, estilos del feedback), QA (V2-21), Performance (V2-20/V2-34), Producer.

## 0. Resumen de decisiones

1. **Fuente única: el log, numerado.** Cada entrada de `state.log` lleva ahora `log_seq:int` (1, 2, 3… creciente en la partida; aplicado en `types.gd`, ver §2). Las sesiones emiten en `state_changed(rev, events)` **las entradas de log nuevas** (`log_seq` > último emitido), en orden de `log_seq`. Así local y en línea producen exactamente el mismo flujo, y la deduplicación es trivial.
2. **El bus no bloquea al motor.** `PresentationBus.ingest()` solo traduce entradas a `FeedbackItem` y las encola (O(n), sin nodos, sin `await`, sin llamar a la sesión). Las animaciones arrancan en `_process`, un fotograma después, cuando la mesa ya aplicó la vista nueva. La sesión y los bots siguen a su ritmo; no hay contrapresión en v0.2.
3. **Visibilidad en dos filtros.** Al ingerir: se descartan entradas que ningún jugador local puede ver (defensa en profundidad). Al **arrancar** cada feedback: si `visible_to` no está vacío y no contiene al que mira **en ese momento**, se descarta (`feedback_dropped(item, "private")`). Mientras se muestra "Pasa el dispositivo" la cola está **bloqueada** (no arranca nada).
4. **Cola por carriles.** Un carril por panel de mago (`panel:<pid>`) y un carril `banner` para "carta jugada". Los carriles de panel se solapan (números apilados, desfase 250 ms) y cada feedback dura ≥ 1 s; el `banner` es exclusivo y descarta los pendientes más viejos si se acumula.
5. **Refresh de la mesa: incremental para paneles y centro.** Los `PlayerPanel` se conservan por `pid` y solo se reconstruyen si cambia el conjunto/orden de rivales o el ancho; el feedback se dibuja en una **capa superpuesta** (`FeedbackLayer`), no dentro de los paneles, así que sobrevive a cualquier reconstrucción. La mano se queda como está en v0.2.

## 1. Lo que hay hoy (estudio del código, 2026-10-13)

- `Game.reduce` devuelve `events` y los copia a `state.log` (`Game._append_log`, recorte a `config.log_limit` = 200).
- `LocalSession._after_change(events)` emite `state_changed(rev, shown)` con los `events` de `reduce` filtrados: públicos o visibles para **algún** jugador local (en hot-seat, varios). `start()` emite `[]`.
- **Hueco real:** el handler `OP_CUSTOM` de *Not Enough Mana* (`EventEffects.mod_not_enough_mana`) escribe su `LOG_MANA_CHANGED` **directamente en `state.log`**: no aparece en los `events` de `reduce`. Con el flujo actual, esa pérdida de maná no daría feedback (ver fila pendiente en `docs/CAMBIOS-TIPOS.md`). Con la decisión 1 entra en el flujo.
- **En línea no hay `events` de `reduce`** en el cliente: solo recibe la vista (`public` + `private/{uid}`, log recortado a `view_log_limit` = 50, sin ids). Sin un número por entrada, el cliente no puede saber qué es nuevo sin comparar diccionarios (frágil: dos `LOG_POTION` o dos `LOG_DAMAGE` iguales son posibles) ni sobrevivir a saltos de `rev` (Firebase entrega solo el último valor).
- `Types.compose_view` concatena log público + privado (el privado al final): el orden mezclado no es cronológico. El bus ordena por `log_seq`, así que no hace falta cambiar `compose_view` ahora.
- Ninguna de las 5 entradas del criterio (`LOG_DAMAGE`, `LOG_HEAL`, `LOG_MANA_CHANGED`, `LOG_POTION`, `LOG_ELIMINATED`) ni `LOG_CARD_PLAYED` es privada hoy; las privadas son `LOG_CARD_DRAWN` y `LOG_EFFECT` con `what = "card_stolen_private"`. El bus filtra igualmente de forma genérica: si mañana un efecto emite una de estas con `visible_to`, sigue siendo correcto.
- Pagar el coste de una carta (`Damage.pay_mana`) **no** genera `LOG_MANA_CHANGED`; el coste viaja en `LOG_CARD_PLAYED.data.cost`. El feedback de "carta jugada" lo muestra (−coste en el panel del que lanza).
- `TableScreen._refresh()` llama a `_rebuild_rivals()` (hace `queue_free` de todos los paneles rivales y crea otros) y `_rebuild_center()` (vacía y rehace) en **cada** cambio de estado; `PlayerPanel.update_player` hace `_rebuild()` (borra y crea hijos) y su `_style()` sobrescribe `modulate`. Cualquier tween o nodo hijo puesto en un panel muere en el siguiente `_refresh` (con bots, cada 0,2-0,9 s).
- `LogText.format` usa `data.amount` para `LOG_MANA_CHANGED`, pero el motor escribe `data.delta` (sale siempre "+0"). No es del bus; va a V2-16 (registro).

## 2. Contrato de datos (aplicado en `src/engine/types.gd`, aditivo)

- `Types.make_log_entry(...)` añade la clave `"log_seq": 0`. `normalize_state` la rellena con 0 en estados antiguos (usa `make_log_entry` como plantilla).
- `Types.stamp_log_seq(entries: Array) -> int`: numera, en orden, las entradas finales con `log_seq <= 0` a continuación de la última numerada (o desde 1). Cubre también las que un `OP_CUSTOM` escribió directamente en `state.log`. Devuelve el último número.
- `Types.last_log_seq(entries: Array) -> int`: mayor `log_seq` (0 si ninguna).
- Invariante (lo garantiza la parte A): en `state.log` los `log_seq` son > 0, estrictamente crecientes y consecutivos dentro de lo que queda tras el recorte. El contador no se guarda aparte: el siguiente número es `log_seq` de la última entrada + 1 (el log nunca se vacía del todo al recortar).
- Limitación conocida: la entrada de *Not Enough Mana* se escribe en el log **antes** que los `events` de la acción que la provoca, así que su `log_seq` es menor que el del `LOG_DAMAGE` que la causó (el feedback de maná sale un instante antes que el de daño, en el mismo panel). Se arregla cuando se resuelva la fila "handlers `OP_CUSTOM` sin `events`" de `docs/CAMBIOS-TIPOS.md`; no bloquea v0.2.
- Los `events` que devuelve `reduce` son copias tomadas antes de numerar: **no** llevan `log_seq`. Nadie debe usar `r.events` para presentación; la fuente es `state.log`.

## 3. Contrato de sesión (`GameSession.state_changed`)

`signal state_changed(rev: int, events: Array)` pasa a significar, en todas las implementaciones:

> `events` = entradas de log con `log_seq` mayor que la última emitida por esta sesión, **ordenadas por `log_seq`**, visibles para algún jugador local (públicas, o con algún pid local en `visible_to`). Cada entrada se emite **una sola vez** por sesión. Al arrancar (`start`) se emite `[]` y la base es el `last_log_seq` del log inicial.

- **LocalSession / anfitrión:** leen de `state.log` completo (ver parte A).
- **Cliente en línea (B1, futuro):** tras componer la vista (`Types.compose_view(public, private, uid)` y `Types.normalize_state`), `events` = entradas de `view.log` con `log_seq > _last_log_seq`, ordenadas por `log_seq`; actualiza `_last_log_seq`. Si el primer `log_seq` nuevo es > `_last_log_seq + 1` (más de 50 entradas perdidas por un salto de `rev`), emite lo que hay; el bus lo cuenta como `gap` y no falla. Se documenta en `docs/ARQUITECTURA.md`.
- `FakeSession` (maqueta de UI) puede seguir emitiendo `[]`.

## 4. Diseño del bus (`src/ui/presentation/`, todo nuevo)

Tres scripts lógicos sin dependencias de la mesa + una capa visual que hace V2-22.

### 4.1 `feedback_mapper.gd` — `class_name FeedbackMapper extends RefCounted` (estático, puro)

Constantes (viven aquí, no en `types.gd`: son de la UI):

```gdscript
const FB_DAMAGE: String = "damage"
const FB_HEAL: String = "heal"
const FB_MANA: String = "mana"
const FB_POTION: String = "potion"
const FB_ELIMINATED: String = "eliminated"
const FB_CARD_PLAYED: String = "card_played"
const LANE_BANNER: String = "banner"
const DUR_PANEL_MS: int = 1200       # daño, curación, maná, poción (>= 1000)
const DUR_ELIMINATED_MS: int = 2000
const DUR_BANNER_MS: int = 1400
const MIN_DURATION_MS: int = 1000

static func lane_for(pid: String) -> String   # "panel:%s" % pid
static func map_entry(entry: Dictionary, rev: int) -> Array[Dictionary]   # 0 o 1 elemento
```

`FeedbackItem` (Dictionary, JSON-seguro, todas las claves siempre presentes):

| clave | tipo | significado |
|---|---|---|
| `log_seq` | int | `log_seq` de la entrada origen (clave de deduplicación) |
| `rev` | int | `rev` del `state_changed` que la trajo |
| `kind` | String | `FB_*` |
| `lane` | String | `panel:<pid>` o `banner` |
| `target` | String | pid del panel afectado (`""` en banner) |
| `actor` | String | `entry.player` |
| `amount` | int | con signo: daño `-dealt`, curación `+amount`, maná `delta`, poción `+amount`, eliminado 0, carta jugada `-cost` |
| `card_id` | String | carta origen si la hay (`""` si no) |
| `targets` | Array | solo `card_played` (copia de `data.targets`); `[]` en el resto |
| `extra` | Dictionary | datos adicionales por tipo (tabla siguiente) |
| `visible_to` | Array | copia de la entrada |
| `duration_ms` | int | ≥ 1000 |

Tabla de traducción (**exactamente 1 item** por entrada de estos tipos; **0** para cualquier otro tipo):

| `entry.type` | `kind` | `target` | `amount` | `extra` |
|---|---|---|---|---|
| `LOG_DAMAGE` | `damage` | `data.target` | `-int(data.dealt)` | `{prevented, element, kind}` (kind = `data.kind` o `""`). Con `dealt == 0` el item existe igual (la capa muestra "Bloqueado" si `prevented > 0`) |
| `LOG_HEAL` | `heal` | `data.target` | `+int(data.amount)` (puede ser 0) | `{}` |
| `LOG_MANA_CHANGED` | `mana` | `data.target` (si vacío, `entry.player`) | `int(data.delta)` | `{missing: int(data.get("missing", 0))}` |
| `LOG_POTION` | `potion` | `entry.player` | `+int(data.amount)` | `{potions: int(data.potions)}` |
| `LOG_ELIMINATED` | `eliminated` | `entry.player` | 0 | `{reason: String(data.reason)}` |
| `LOG_CARD_PLAYED` | `card_played` | `""` | `-int(data.cost)` | `{caster: entry.player}`; `lane = "banner"` |

Regla de carril: `lane_for(target)`; si `target == ""` y el tipo no es `card_played`, se usa `entry.player`; si también está vacío, `banner`. El mapper **no compone texto**: los textos ("Bloqueado", "Bruno → Fireball → Ana") los pone la capa con las cadenas de Narrative (`src/ui/strings.gd`, V2-08). Ampliar a otros tipos (p. ej. `LOG_REACTED` como banner) = añadir una fila aquí; nada más cambia.

### 4.2 `feedback_queue.gd` — `class_name FeedbackQueue extends RefCounted` (puro, determinista)

Reloj propio en ms (`now_ms`, empieza en 0); no lee `Time`. Constantes:

```gdscript
const STAGGER_MS: int = 250          # desfase entre arranques en un mismo carril de panel
const STAGGER_FAST_MS: int = 100     # si el carril tiene >= FAST_BACKLOG pendientes
const FAST_BACKLOG: int = 4
const BANNER_MAX_PENDING: int = 2    # al encolar un 3.º banner pendiente se descarta el más viejo
```

API:

```gdscript
func push(item: Dictionary) -> Array[Dictionary]   # devuelve los items descartados por "skipped" (banner)
func advance(ms: int, viewer: String, blocked: bool) -> Dictionary
	# -> {started: Array[Dictionary], finished: Array[Dictionary], dropped: Array[Dictionary]}
func pending_count() -> int
func active_count() -> int
func is_idle() -> bool             # sin pendientes ni activos
func clear() -> void
```

Algoritmo de `advance(ms, viewer, blocked)` (en este orden):
1. `now_ms += ms`.
2. Termina los activos con `now_ms >= started_at + duration_ms` → `finished`.
3. Si `blocked`, devuelve (no arranca nada; los activos sí terminan).
4. Para cada carril, en orden de creación del carril: mientras haya pendientes y `now_ms >= lane.next_start` (y, si el carril es `banner`, no haya un banner activo):
   - saca el primero (los pendientes de un carril están ordenados por `log_seq`);
   - si `visible_to` no está vacío y no contiene `viewer` → `dropped` con `reason = "private"`, sigue con el siguiente;
   - si no, lo arranca (`started_at = now_ms`), va a `started` y `lane.next_start = now_ms + (STAGGER_FAST_MS si quedan >= FAST_BACKLOG pendientes, si no STAGGER_MS)`; en el carril `banner`, `next_start = now_ms + duration_ms`.
   Como `next_start > now_ms` tras arrancar, cada llamada arranca como mucho 1 item por carril (salvo los descartados por privados).
5. Devuelve las tres listas. Cada item descartado lleva `extra.drop_reason` (`"private"` o `"skipped"`).

Con bots a 200-900 ms por acción, los carriles de panel nunca se quedan atrás más de unos cientos de ms (se solapan); el banner sí podría, y por eso descarta pendientes viejos (el registro de 3 líneas, V2-16, conserva la información).

### 4.3 `presentation_bus.gd` — `class_name PresentationBus extends Node`

```gdscript
signal feedback_started(item: Dictionary)
signal feedback_finished(item: Dictionary)
signal feedback_dropped(item: Dictionary, reason: String)   # "private" | "skipped"

var auto_advance: bool = true      # false en tests: se avanza a mano con advance()/drain()

func bind(p_session: GameSession, p_viewer_provider: Callable, baseline_view: Dictionary) -> void
func unbind() -> void
func ingest(rev: int, events: Array) -> void
func set_blocked(value: bool) -> void
func is_blocked() -> bool
func advance(ms: int) -> void
func drain(max_ms: int = 120000, step_ms: int = 50) -> void   # advance(step_ms) hasta is_idle() o max_ms; respeta el bloqueo (si está bloqueado solo terminan los activos)
func is_idle() -> bool
func last_seq() -> int
func stats() -> Dictionary
	# {produced: {kind: n}, started: {kind: n}, dropped: {"private": n, "skipped": n}, gaps: n, unnumbered: n}
```

Comportamiento:
- `bind`: guarda la sesión y conecta `session.state_changed` a `ingest` (si no lo estaba). `_last_seq = Types.last_log_seq(baseline_view.get("log", []))` → **no se repite la historia** al entrar en la mesa ni al reconectar. `p_viewer_provider` es un `Callable` sin argumentos que devuelve el pid que mira ahora (`""` = espectador). `unbind` desconecta y vacía la cola.
- `ingest(rev, events)`:
  1. Copia y ordena `events` por `log_seq`.
  2. Para cada entrada: si `log_seq > 0` y `log_seq <= _last_seq` → se ignora (duplicado). Si `log_seq == 0` (sesión antigua sin parte A): se acepta sin poder deduplicar y suma `stats.unnumbered` (y un único `push_warning`). Si `log_seq > _last_seq + 1` y `_last_seq > 0` → suma `stats.gaps`.
  3. Filtro de ingesta: si `visible_to` no está vacío y no comparte ningún pid con `session.get_local_player_ids()` → se ignora (no se cuenta como producido).
  4. `FeedbackMapper.map_entry(entry, rev)` → por cada item: `stats.produced[kind] += 1`, `queue.push(item)`; los descartados por `push` emiten `feedback_dropped(item, "skipped")`.
  5. `_last_seq = max(_last_seq, log_seq)`.
  **Nunca** arranca items, crea nodos, hace `await` ni llama a la sesión.
- `_process(delta)`: si `auto_advance`, `advance(int(delta * 1000.0))`.
- `advance(ms)`: `queue.advance(ms, viewer_provider.call() si es válido, si no "", _blocked)`; emite `feedback_finished` / `feedback_dropped(item, "private")` / `feedback_started` (en ese orden) y actualiza `stats.started`.
- Nueva partida ("Jugar otra vez"): la mesa crea una sesión nueva y un bus nuevo, o llama a `bind` otra vez (resetea `_last_seq` y la cola). Por eso no hace falta detectar `log_seq` que vuelven a 1.

### 4.4 Hot-seat y entradas privadas (resumen operativo)

| Situación | Qué pasa |
|---|---|
| Entrada pública | Se encola; se ve cuando le toque, quien sea que mire. |
| Privada para el que mira | Se encola y se ve. |
| Privada para otro jugador local (p. ej. p1 roba y mira p2) | Se encola (algún local puede verla) pero **se descarta al arrancar** porque `viewer_provider()` no está en `visible_to`. No se reprograma para cuando vuelva p1: la información ya está en su registro. |
| Privada para nadie local (en línea no llega; en local, bots) | Se ignora en la ingesta. |
| Se muestra "Pasa el dispositivo" | La mesa llama `set_blocked(true)`; nada arranca (lo que ya estaba en marcha termina detrás de la pantalla). Al confirmar, la mesa fija el nuevo `viewer_id`, aplica la vista y llama `set_blocked(false)`: el nuevo jugador ve lo que le pasó mientras tanto, y lo privado del anterior se descarta. |
| Ventana de reacción, diálogos, aviso de evento | **No** bloquean (la capa va por debajo de los overlays modales, pero el feedback ya arrancado termina y el siguiente sigue; bloquear aquí retrasaría todo varios segundos). |

### 4.5 Capa visual (`feedback_layer.gd`, en V2-22, no en V2-14)

- `class_name FeedbackLayer extends Control`, rect completo, `mouse_filter = MOUSE_FILTER_IGNORE`, hija de la mesa **por encima** de rivales/panel propio y **por debajo** de `_reaction_overlay`, `_dialog_overlay`, `_notice_overlay` y `_pass_screen`.
- `var anchor_provider: Callable` → `func(pid: String) -> Control` (la mesa expone `panel_for(pid)`: panel propio si `pid == viewer_id`, si no el rival; `null` si no existe).
- Al recibir `feedback_started(item)`: toma `anchor.get_global_rect()` **en ese momento**, crea (o saca de un pool de ≤ 12) un número flotante y un destello (`ColorRect` encima del rect del panel, no `modulate` del panel, porque `PlayerPanel._style()` lo sobrescribe) y anima con un `Tween` propio de duración `item.duration_ms`. Banner arriba en el centro. Si `anchor` es `null`, no dibuja nada (el item cuenta igual).
- Colores, tamaños (≥ 22 px a 1080) e iconos: Technical Artist (V2-18) y Art (V2-19). Textos: `strings.gd` (V2-08).
- La capa no conoce la sesión ni el estado: solo items.

## 5. Decisión de refresh de la mesa

**Decisión: incremental en paneles y centro; la mano sigue como está.** Motivo: el feedback va en una capa aparte y no depende de ello, pero reconstruir 3-5 paneles con sus `CardView` y `HFlowContainer` cada 0,2-0,9 s (bots) cuesta tiempo de fotograma justo cuando hay tweens, y con el abanico de rivales provoca un salto de layout (`_layout_rivals.call_deferred`). Es un cambio pequeño y local.

Reglas (las aplica V2-22 en el módulo de rivales/centro que fije `docs/TECNICO/division-table.md`; V2-13 **no** las aplica porque no cambia comportamiento):
1. Rivales: guardar `_rival_key = "<pid1>,<pid2>,…|<ancho redondeado>"`. Si la clave no cambia, llamar a `update_player(...)` sobre los paneles existentes (mapa `pid -> PlayerPanel`) y **no** volver a llamar a `_layout_rivals`. Si cambia (otro jugador mira en hot-seat, cambia el ancho), reconstruir como hoy.
2. `PlayerPanel.update_player`: calcular una firma (`JSON.stringify(player)` + `is_turn`, `pickable`, `picked`) y salir sin `_rebuild()` si no ha cambiado.
3. Centro: firma `(deck_count, discard.size(), iid de la carta de arriba, iid del evento, ancho)`; si no cambia, no se toca.
4. Mano (`HandView`) y barra de modo: sin cambios en v0.2.
5. Exponer `TableScreen.panel_for(pid: String) -> Control` para el `anchor_provider`.
6. Performance (V2-20 antes, V2-34 después) mide el turno de 3 bots con feedback: presupuesto 16 ms/fotograma. Si se supera, siguiente paso = pool de `CardView` en paneles; no antes.

**Nota de implementación (V2-22, verificada en `src/` el 2026-10-13):** las reglas 1, 2, 3 y 5 están aplicadas tal cual en `TablePlayers` (`_rival_key`, `rebuild_rivals`, `panel_for`), `PlayerPanel.update_player` (`_sig`) y `TableCenter.rebuild` (`_sig`). `TableScreen.panel_for` solo reenvía a `TablePlayers.panel_for`. Diferencia con la regla 1: el ancho **no** forma parte de la clave de rivales; un cambio de ancho no reconstruye y `_layout_rivals` ajusta el ancho de los paneles. En el centro el ancho sí está en la firma.

## 6. Puntos de enganche (V2-22, en la mesa)

| Dónde (función actual de `table.gd`; el módulo destino lo fija V2-05) | Qué añade |
|---|---|
| `bind_session` | Crear `PresentationBus` (hijo de la mesa) y `FeedbackLayer`; `bus.bind(session, func() -> String: return viewer_id, v)`; `bus.feedback_started.connect(layer.play)`; `layer.anchor_provider = panel_for`. El bus conecta su propio `state_changed`: el orden respecto a `_on_state_changed` da igual porque nada arranca hasta `_process`. |
| Cada `_pass_screen.show_for(...)` (en `bind_session` y `_on_state_changed`) | `bus.set_blocked(true)` |
| `_on_pass_confirmed`, después de `set_view` | `bus.set_blocked(false)` |
| `_check_game_over` | Nada: el feedback de la última eliminación termina detrás del diálogo de fin. |
| `_rebuild_rivals`, `_rebuild_center`, `PlayerPanel.update_player` | Reglas de §5. |

## 7. Tareas técnicas

### V2-14 parte A — numeración del log y eventos de sesión desde el log (Developer)
- **Archivos:** `src/engine/game.gd` (solo `_append_log`), `src/session/local_session.gd`, `src/session/game_session.gd` (solo el comentario de `state_changed`), `tests/engine/test_log_seq.gd` (nuevo), `tests/integration/test_session_events.gd` (nuevo). **Petición al Producer:** añadir estos archivos a V2-14 (hoy solo lista `src/ui/presentation/*.gd` y el test del bus) o abrir V2-14a en serie antes de la parte B. No chocan con el lote O1 (V2-13 toca la mesa y sus tests; V2-17 toca `src/ai/`).
- **Cambios:**
  1. `Game._append_log(s, events)`: tras añadir las copias de `events`, llamar `Types.stamp_log_seq(s["log"])` **antes** del recorte por `log_limit`.
  2. `LocalSession`: nueva var `_last_log_seq: int`. En `start()`: `_last_log_seq = Types.last_log_seq(state.log)` y se sigue emitiendo `[]`. `_after_change` deja de usar el parámetro `events` para emitir: recorre `state.log` desde el final mientras `log_seq > _last_log_seq`, invierte, aplica el filtro de visibilidad actual (públicas o con algún pid local) y actualiza `_last_log_seq` con el último `log_seq` visto (aunque la entrada se haya filtrado). El resto de `_after_change` no cambia.
  3. Comentario de `GameSession.state_changed` con el contrato de §3.
- **Pruebas:** (a) tras 30 acciones en una partida de 4 con `log_limit` grande, los `log_seq` de `state.log` son 1..N consecutivos; (b) con `log_limit = 10` se sigue numerando sin repetir tras el recorte; (c) con *Not Enough Mana* activo y un daño, la `LOG_MANA_CHANGED` de NEM tiene `log_seq` y llega en `state_changed`; (d) en una partida de 4 bots con `log_limit` grande, la unión de `events` emitidos = entradas públicas de `state.log` (mismo orden, sin duplicados); (e) en hot-seat 2 humanos + 1 bot, un `LOG_CARD_DRAWN` de p1 llega en `events` y uno de un bot no.
- **Hecho cuando:** pruebas nuevas en verde, `bash tools/test.sh` sin regresiones (≥ 425) y `bash tools/check_warnings.sh` → OK.

### V2-14 parte B — bus de presentación sin tocar la mesa (Developer)
- **Archivos:** `src/ui/presentation/feedback_mapper.gd`, `src/ui/presentation/feedback_queue.gd`, `src/ui/presentation/presentation_bus.gd` (nuevos), `tests/integration/test_presentation_bus.gd` (nuevo). `feedback_layer.gd` **no** entra aquí (V2-22).
- **Contrato que respeta:** §2-§4 de este documento; `Types.LOG_*`, `Types.last_log_seq`; la UI solo habla con `GameSession`.
- **Hecho cuando:** pasan los tests de §8, suite completa en verde, `check_warnings.sh` OK, y QA valida (V2-21).

### V2-22 (ítem 1) — capa visual y enganche en la mesa
- Archivos según V2-05 (módulo de rivales/centro de la mesa, cáscara si hace falta `panel_for`), `src/ui/components/player_panel.gd` (firma en `update_player`), `src/ui/presentation/feedback_layer.gd` (nuevo). Contrato: §4.5, §5 y §6. Captura de un daño con número flotante y destello.

## 8. Criterio de test (V2-14 parte B: `tests/integration/test_presentation_bus.gd`)

Todos con `bus.auto_advance = false`; el tiempo se avanza con `advance(ms)`/`drain()`.

1. **Mapper (unidad).** Para cada fila de §4.1, una entrada construida con `Types.make_log_entry` produce **exactamente 1** item con `kind`, `target`, `amount`, `lane` y `duration_ms >= 1000` correctos; `LOG_TURN_STARTED`, `LOG_CARD_DRAWN`, `LOG_EFFECT`, `LOG_EVENT_DRAWN` producen 0.
2. **Partida de 4 (criterio de LINEAMIENTOS §3).** `LocalSession.create` con 4 bots, semilla fija, `config.log_limit = 100000`, `auto_run_bots = false`; bus enlazado con viewer `""`. Bucle: `run_bots(1)` + `bus.advance(50)` hasta `status == finished` (tope de pasos), y al final `bus.drain()`. Con `E[k]` = entradas públicas de `state.log` del tipo `k`:
   - para `k` en {`LOG_DAMAGE`, `LOG_HEAL`, `LOG_MANA_CHANGED`, `LOG_POTION`, `LOG_ELIMINATED`}: `stats.produced[kind] == E[k] == stats.started[kind]`, y el multiconjunto de `log_seq` recogidos en `feedback_started` es exactamente el de esas entradas (**1 feedback exacto por entrada, ninguno repetido, ninguno perdido**);
   - la semilla se elige para que los cinco `E[k]` sean > 0 (el test lo afirma, para que no pase en vacío);
   - `card_played`: `produced == E[LOG_CARD_PLAYED]` y `started + skipped == produced`;
   - todo item arrancado cumple `duration_ms >= 1000` y termina (`feedback_finished`) tras `drain()`; `bus.is_idle()`.
3. **No bloquea.** Justo después de `ingest` (sin `advance`) `stats.started` no cambia y no se ha creado ningún nodo hijo; la partida avanza con `run_bots` sin depender del bus.
4. **Deduplicación.** Ingerir dos veces los mismos `events` → `produced` no cambia. `bind` con una vista cuyo log llega a `log_seq = 40` e `ingest` de entradas 35-45 → solo se producen 41-45.
5. **Orden.** Ingerir `[seq 6, seq 5]` del mismo panel → arrancan en el orden 5, 6.
6. **Privadas en hot-seat** (sesión de prueba que extiende `GameSession`, `get_local_player_ids() = ["p1", "p2"]`): un `LOG_MANA_CHANGED` con `visible_to = ["p1"]` y un `LOG_DAMAGE` público.
   - viewer `p2`: arranca solo el daño; el maná sale en `feedback_dropped(…, "private")`.
   - viewer `p1`: arrancan los dos.
   - `set_blocked(true)`, ingerir, `advance(5000)` → 0 arrancados; cambiar viewer a `p1`, `set_blocked(false)`, `advance` → arrancan.
   - una entrada con `visible_to = ["p3"]` (p3 no es local) no se produce.
7. **Banner.** 4 `LOG_CARD_PLAYED` seguidos → como mucho 1 banner activo a la vez; `started + skipped == 4`.
8. **Sin `log_seq`** (entradas con 0): se producen y `stats.unnumbered` lo refleja.

## 9. Riesgos y fuera de alcance

- **Desfase visual:** el panel muestra ya el valor final mientras el número flotante se anima. Aceptado en v0.2; "contar hacia abajo" el chip es v0.3.
- **Contrapresión** (que los bots esperen al feedback): no en v0.2. Si M12 dice que no se sigue, opción preparada: `LocalSession.bot_delay_*` mayor cuando `bus.pending_count() > N` (requiere una decisión y un método nuevo en la sesión; no ahora).
- **Animaciones de cartas, sonido y vibración:** v0.3; se colgarán de `feedback_started` sin tocar el bus.
- **`compose_view` no ordena por `log_seq`:** el bus ordena; si el registro (V2-16) necesita orden cronológico en hot-seat, que ordene por `log_seq` en la UI o se pide aquí un cambio de `compose_view`.
