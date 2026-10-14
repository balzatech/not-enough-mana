# División de `src/ui/screens/table.gd` en módulos (V2-05)

Autor: Lead Programmer. Fecha: 2026-10-13. Lo ejecuta **V2-13** (Developer) sin cambiar comportamiento ni apariencia.
Base medida: `table.gd` = 1590 líneas, 90 funciones; `bash tools/test.sh` -> **425/425** (28 scripts, 7652 asserts) el 2026-10-13.

## 1. Objetivo y reglas

- Cada ítem de v0.2 que toca la mesa debe poder asignarse a **un módulo propio**, para que dos tareas paralelas no editen el mismo archivo.
- Ningún módulo pasa de **~400 líneas** (objetivo: ≤ 300 tras V2-13, con margen para v0.2).
- La **cáscara** `src/ui/screens/table.gd` (`class_name TableScreen`) mantiene **toda** la API que usan hoy `src/ui/ui_nav.gd`, `src/session/local_session.gd`, los tests y los scripts de captura (ver §5). `table.tscn` no cambia.
- V2-13 es una refactorización **mecánica**: se mueven funciones, no se reescriben. Ningún texto, tamaño, color, orden de nodos ni orden de llamadas cambia.

## 2. Patrón: contexto compartido + módulos `Node` hijos de la mesa

```
TableScreen (Control, cáscara)            src/ui/screens/table.gd
 ├─ ctx: TableContext (RefCounted)        estado compartido + consultas + servicios
 ├─ widgets (en el mismo orden que hoy), construidos por los módulos
 └─ módulos (Node, hijos de la mesa, se añaden al final de _build_ui)
     TableSync  TableMenu  TablePlayers  TableCenter  TableHand  TableActions
     TableFlow  TableModeBar  TableDialogs  TablePrompts  TableNotices  TableGameOver
```

**Por qué así** (alternativas descartadas: una sola clase con `extends` encadenados, que no reduce los conflictos de edición; señales entre módulos, que pierde el tipado y oculta el orden síncrono que hoy importa):

1. **`TableContext` (RefCounted)** guarda el estado que leen o escriben **dos o más** módulos, las consultas puras sobre la vista y referencias tipadas a cada módulo (`ctx.flow`, `ctx.dialogs`...). Los módulos se llaman entre sí **a través de `ctx`**, con métodos tipados y síncronos, igual que hoy dentro de un único archivo.
2. **Módulos = `Node`** hijos de la mesa (base común `TableModule`). Se liberan con la mesa (sin fugas ni huérfanos en GUT). `ctx` guarda referencias a `Node`, que no cuentan como referencias de `RefCounted`, así que no hay ciclos de memoria.
3. **Estado de un solo dueño** (cola de avisos, `_game_over_shown`, `_pending_viewer`...) vive en su módulo, no en `ctx`.
4. **Servicios de la cáscara** que usan los módulos, siempre por `ctx`: `ctx.refresh()`, `ctx.emit_action(a)`, `ctx.toast(text)`, `ctx.zoom(card, def)`. Para operaciones de nodo (tween, `get_tree()`, `is_inside_tree()`, `size`, emitir `play_again_requested`) se usa `ctx.screen` (tipo `TableScreen`). Un módulo **no** llama a otros métodos de la cáscara.
5. **Un módulo no toca widgets de otro**: usa métodos (`ctx.prompts.hide_reaction()`, `ctx.dialogs.close()`, `ctx.sync.hide_pass_screen()`).
6. **Nadie guarda copias** de `ctx.view`, `ctx.opts`, `ctx.selected`... entre llamadas: se reasignan en cada `set_view` (y `selected` se reasigna en varios sitios).

Comprobado en un proyecto de prueba con **Godot 4.7.2** y los mismos warnings que `tools/check_warnings.sh` (en error): referencias tipadas cíclicas `TableContext` <-> `TableFlow`, el alias de enum `const Step = TableContext.Step` en la cáscara (`TableScreen.Step.TARGETS` sigue valiendo) y una propiedad con getter tipada `var _step: TableContext.Step`. **0 warnings, ejecución correcta.**

### 2.1 Esqueleto (contrato para V2-13)

```gdscript
# src/ui/screens/table/table_module.gd
class_name TableModule
extends Node
var ctx: TableContext
func setup(p_ctx: TableContext) -> void:
	ctx = p_ctx
## Botones de PromptDialog. true = consumido (la mesa no hace nada más);
## false = no es mío o "sigue" (cae en la cola común de TableDialogs).
func on_dialog_button(_id: String) -> bool:
	return false
```

```gdscript
# src/ui/screens/table/table_context.gd
class_name TableContext
extends RefCounted
enum Step { NONE, TARGETS, PAYMENT, CARDS }
const DRINK_PROMPTS: Array[String] = [Types.PROMPT_MANA_SHORTFALL, Types.PROMPT_DRINK_OR_SUFFER]
const FLOW_KINDS_PLAY: Array[String] = ["play", "react"]
var screen: TableScreen
var session: GameSession = null
var viewer_id: String = ""
var view: Dictionary = {}
var local_ids: Array[String] = []
var opts: ActionOptions = ActionOptions.new()
var selected: Array[int] = []
var pay_table: Array[int] = []
var flow_data: Dictionary = {}      # antes _flow (el nombre "flow" es el módulo)
var pflow: PlayFlow = null
var step: Step = Step.NONE
var shown_prompt_id: int = -1
var modules: Array[TableModule] = []   # orden = orden de consulta de on_dialog_button
var sync: TableSync
var menu: TableMenu
# ... players, center, hand, actions, flow, mode_bar, dialogs, prompts, notices, game_over
```

Cáscara: `var _ctx: TableContext` se crea en `_init()` junto con **todas** las instancias de módulo (`setup(_ctx)` y registro en `ctx`), para que `set_view`/`bind_session`/`_queue_event_notices` llamados antes de `_ready` sigan funcionando como hoy. `_build_ui()` pide a cada módulo sus widgets y los añade **en el orden actual** (§4.1) y, al final, hace `add_child` de los módulos.

## 3. Módulos definitivos

Carpeta `src/ui/screens/table/`. Líneas = estimación tras V2-13 (suma de las funciones movidas + construcción de widgets + cabecera).

| Archivo | `class_name` | Responsabilidad | Widgets que construye y posee | Líneas |
|---|---|---|---|---|
| `src/ui/screens/table.gd` | `TableScreen` | Cáscara: señales, API pública, composición de la UI, orquestación de `refresh()`, servicios (acción, toast, zoom), registro (`ActionLog`), bloque de compatibilidad | margen/raíz, `_log`, `_toast`, `_zoom` | ~260 |
| `table_module.gd` | `TableModule` | Base de los módulos | — | ~15 |
| `table_context.gd` | `TableContext` | Estado compartido, consultas puras sobre la vista, servicios delegados, `make_overlay` estático | — | ~250 |
| `table_sync.gd` | `TableSync` | Sesión y hot-seat: cambios de estado, decisor local, pantalla "Pasa el dispositivo", errores, fin desde la sesión | `_pass_screen` | ~110 |
| `table_menu.gd` | `TableMenu` | Barra superior (Menú, turno, "Rompió la regla"), menú de partida, denuncia de Curse of Rules | `_menu_btn`, `_turn_label`, `_rule_btn` | ~110 |
| `table_players.gd` | `TablePlayers` | Paneles: abanico de rivales y panel propio | `_rival_fan`, `_rival_panels`, `_own_panel` | ~110 |
| `table_center.gd` | `TableCenter` | Mazo, descarte, evento activo | `_center` | ~70 |
| `table_hand.gd` | `TableHand` | Mano, selección normal, pista y motivo de "no jugable" | `_hint`, `_hand` | ~130 |
| `table_actions.gd` | `TableActions` | Fila Jugar/Intercambiar/Descartar/Terminar y botón de poción (incl. aviso Too Much Mana) | `_action_row`, `_play_btn`, `_exchange_btn`, `_discard_btn`, `_end_btn`, `_drink_btn` | ~150 |
| `table_flow.gd` | `TableFlow` | Máquina de jugada: objetivos, carta objetivo, opción extra, regla, elección de cartas, artefactos | — | ~290 |
| `table_mode_bar.gd` | `TableModeBar` | Barra de modo (pago y elección de cartas): textos, Confirmar/Scroll/Cancelar, toques de mano en PAYMENT/CARDS | `_mode_bar`, `_mode_label`, `_mode_confirm`, `_mode_cancel`, `_mode_extra` | ~150 |
| `table_dialogs.gd` | `TableDialogs` | Anfitrión de `PromptDialog`: abrir/cerrar, botones extra, despacho de botones a los módulos | `_dialog`, `_dialog_overlay` | ~120 |
| `table_prompts.gd` | `TablePrompts` | Ventana de reacción y prompts del motor (qué superposición se abre y cuándo) | `_reaction`, `_reaction_overlay` | ~230 |
| `table_notices.gd` | `TableNotices` | Avisos modales: eventos nuevos y revelaciones privadas | `_notice_panel`, `_notice_overlay` | ~100 |
| `table_game_over.gd` | `TableGameOver` | Detección y diálogo de fin de partida, "Jugar otra vez" | — (usa `TableDialogs`) | ~55 |
| *(V2-22)* `table_feedback.gd` | `TableFeedback` | Consumidor del bus de presentación en la mesa (no lo crea V2-13) | capa de feedback | — |

Total ≈ 2150 líneas (sube por cabeceras, métodos públicos y el bloque de compatibilidad; es esperado).

## 4. Tabla función -> módulo (las 90 funciones)

Notación: `ctx.x` = miembro de `TableContext`. "Alias" = se queda en la cáscara una función o propiedad de una línea que reenvía (bloque de compatibilidad, §5). Las líneas son las del `table.gd` actual.

| # | Función actual (línea, longitud) | Destino | Nombre nuevo / notas |
|---|---|---|---|
| 1 | `_ready` (79, 13) | cáscara | sin cambios |
| 2 | `_build_ui` (92, 140) | cáscara + módulos | la cáscara crea margen/raíz, `_log`, `_toast`, `_zoom` y pide el resto a los módulos en el orden de §4.1; los bloques de construcción se mueven a `build_*()` de cada módulo |
| 3 | `_action_button` (232, 8) | `TableActions` | `_action_button` |
| 4 | `_make_overlay` (240, 24) | `TableContext` | `static func make_overlay(content, width) -> Control` **sin** `add_child` (lo hace la cáscara, en el mismo orden) |
| 5 | `bind_session` (264, 25) | cáscara + `TableSync` | la cáscara conserva la firma, guarda la sesión, `local_ids`, `viewer_id`, conecta `state_changed`/`error`/`game_over` a `ctx.sync.*` y llama `ctx.sync.on_bound()` (cola de avisos + decisor + pantalla de paso + `set_view`) |
| 6 | `_on_state_changed` (289, 25) | `TableSync` | `on_state_changed` |
| 7 | `_on_pass_confirmed` (314, 15) | `TableSync` | `on_pass_confirmed` |
| 8 | `_on_session_error` (329, 8) | `TableSync` | `on_session_error` |
| 9 | `_on_game_over` (337, 5) | `TableSync` | `on_game_over` |
| 10 | `show_toast` (342, 14) | cáscara | público; `ctx.toast()` delega aquí (el tween sigue siendo de la mesa) |
| 11 | `set_view` (356, 11) | cáscara | sin cambios (escribe `ctx.view`, `ctx.viewer_id`, `ctx.opts`) |
| 12 | `options` (367, 4) | cáscara | devuelve `ctx.opts` |
| 13 | `_me` (371, 4) | `TableContext` | `me()`; alias `_me` |
| 14 | `_name_of` (375, 5) | `TableContext` | `static name_of(v, pid)` |
| 15 | `_names` (380, 8) | `TableContext` | `names()` |
| 16 | `_turn_info` (388, 4) | `TableContext` | `turn_info()` |
| 17 | `_is_my_turn` (392, 4) | `TableContext` | `is_my_turn()` (hoy sin uso; se conserva) |
| 18 | `_playing` (396, 4) | `TableContext` | `playing()` |
| 19 | `_my_prompts` (400, 10) | `TableContext` | `my_prompts()` |
| 20 | `_can_act` (410, 4) | `TableContext` | `can_act()` |
| 21 | `_refresh` (414, 25) | cáscara | `refresh()` orquestador, orden fijo de §4.2 |
| 22 | `_refresh_own` (439, 6) | `TablePlayers` | `refresh_own(me)` |
| 23 | `_refresh_buttons` (445, 22) | `TableActions` | `refresh_buttons(me)`; las 3 últimas líneas (visibilidad de fila/barra y `_update_mode_bar`) pasan a `ctx.mode_bar.refresh()`, llamado en el mismo punto |
| 24 | `_exchange_cost` (467, 6) | `TableContext` | `exchange_cost()` |
| 25 | `_drink_text` (473, 9) | `TableContext` | `drink_text(me)` (lo usan acciones y prompts) |
| 26 | `_drink_would_eliminate` (482, 8) | `TableContext` | `drink_would_eliminate()` |
| 27 | `_refresh_hand` (490, 28) | `TableHand` | `refresh_hand(me)` |
| 28 | `_refresh_hint` (518, 24) | `TableHand` | `refresh_hint(me)` |
| 29 | `_unplayable_reason` (542, 27) | `TableHand` | `unplayable_reason(inst)` (lo usa `TableFlow.begin_play`) |
| 30 | `_rival_list` (569, 11) | `TablePlayers` | `_rival_list` |
| 31 | `_rebuild_rivals` (580, 20) | `TablePlayers` | `rebuild_rivals()` |
| 32 | `_rival_width` (600, 8) | `TablePlayers` | `_rival_width`; `RIVAL_CAP` también |
| 33 | `_layout_rivals` (608, 31) | `TablePlayers` | `_layout_rivals` |
| 34 | `_rebuild_center` (639, 30) | `TableCenter` | `rebuild()` |
| 35 | `_center_column` (669, 9) | `TableCenter` | `_center_column` |
| 36 | `_empty_slot` (678, 8) | `TableCenter` | `_empty_slot` |
| 37 | `_on_center_card_tapped` (686, 6) | `TableCenter` | `_on_card_tapped` |
| 38 | `_show_zoom` (692, 5) | cáscara | `show_zoom(card, def)`; `ctx.zoom()` delega; alias `_show_zoom` |
| 39 | `_on_own_card` (697, 11) | `TableFlow` | `on_own_card` (abre el diálogo de artefacto); alias |
| 40 | `_use_artifact` (708, 21) | `TableFlow` | `_use_artifact` |
| 41 | `_emit_action` (729, 11) | cáscara | `emit_action(a)` (emite `action_requested`); `ctx.emit_action()` delega; cierra el diálogo con `ctx.dialogs.close()` |
| 42 | `_reset_flow` (740, 8) | `TableContext` | `reset_flow()`; alias |
| 43 | `_on_drink` (748, 9) | `TableActions` | `on_drink` (también lo conecta `ReactionPrompt.drink_requested`) |
| 44 | `_request_drink` (757, 31) | `TableActions` | `request_drink(pr_id, confirmed)`; `_warn_prompt_id` pasa a ser estado propio de `TableActions` |
| 45 | `_on_end_turn` (788, 5) | `TableActions` | `_on_end_turn` |
| 46 | `_on_exchange` (793, 5) | `TableActions` | `_on_exchange` |
| 47 | `_on_discard` (798, 5) | `TableActions` | `_on_discard` |
| 48 | `_on_pass_reaction` (803, 4) | `TablePrompts` | `_on_pass_reaction` |
| 49 | `_on_menu` (807, 10) | `TableMenu` | `_on_menu` |
| 50 | `_on_hand_tapped` (817, 39) | `TableHand` + `TableModeBar` | `TableHand.on_hand_tapped(card)`: si `ctx.step` es PAYMENT o CARDS delega en `ctx.mode_bar.on_hand_tapped(iid)` (las dos primeras ramas, idénticas); la rama de selección normal se queda en la mano; alias |
| 51 | `_find_in_hand` (856, 7) | `TableContext` | `find_in_hand(iid)` |
| 52 | `_on_play` (863, 5) | `TableActions` | `_on_play` -> `ctx.flow.begin_play(sel, false)` |
| 53 | `_on_react_card` (868, 6) | `TablePrompts` | `_on_react_card` -> `ctx.flow.begin_play(iid, true)` |
| 54 | `begin_play` (874, 18) | `TableFlow` | `begin_play`; la cáscara conserva `begin_play` público (reenvía) |
| 55 | `_advance_flow` (892, 18) | `TableFlow` | `advance()` |
| 56 | `_advance_play` (910, 37) | `TableFlow` | `_advance_play`; el bloque "entrar en PAYMENT" (4 líneas) se mueve tal cual a `ctx.mode_bar.enter_payment()` (punto de enganche del ítem 4) |
| 57 | `_payment` (947, 9) | `TableContext` | `payment()` |
| 58 | `_allowed` (956, 13) | `TableContext` | `allowed()`; alias |
| 59 | `_flow_targets` (969, 9) | `TableContext` | `flow_targets()`; alias |
| 60 | `_on_panel_tapped` (978, 25) | `TableFlow` | `on_panel_tapped(pid)`; alias |
| 61 | `_update_mode_bar` (1003, 32) | `TableModeBar` | `update()` |
| 62 | `_wildcards_available` (1035, 13) | `TableModeBar` | `_wildcards_available` |
| 63 | `_on_mode_extra` (1048, 15) | `TableModeBar` | `on_mode_extra`; alias |
| 64 | `_on_mode_confirm` (1063, 16) | `TableModeBar` | `_on_mode_confirm` (en PAYMENT llama `ctx.flow.advance()`, en CARDS `ctx.flow.advance_cards()`) |
| 65 | `_advance_flow_cards` (1079, 16) | `TableFlow` | `advance_cards()` |
| 66 | `_cancel_flow` (1095, 6) | `TableFlow` | `cancel()` (lo conecta `_mode_cancel`) |
| 67 | `_find_curse_of_rules` (1101, 9) | `TableContext` | `find_curse_of_rules()` |
| 68 | `_on_break_rule` (1110, 16) | `TableMenu` | `on_break_rule` (prepara `flow_data` y llama `ctx.flow.advance()`); alias |
| 69 | `_open_dialog` (1126, 7) | `TableDialogs` | `open(kind, ...)` misma firma |
| 70 | `_on_dialog_button` (1133, 108) | `TableDialogs` + dueños | `TableDialogs.on_button(id)`: cierra, guarda y limpia `kind`, recorre `ctx.modules` llamando `on_dialog_button(id)` hasta que uno devuelva true; si ninguno, cola común (`kind == "prompt"` -> `ctx.shown_prompt_id = -1`; `refresh()` si hay vista). Reparto de ids en §4.3; alias |
| 71 | `_find_my_artifact` (1241, 8) | `TableContext` | `find_my_artifact(card_id)` |
| 72 | `_card_in_play` (1249, 20) | `TableContext` | `card_in_play(iid)` |
| 73 | `_open_target_card_dialog` (1269, 12) | `TableFlow` | `_open_target_card_dialog` (usa `ctx.dialogs.open_cards/add_button/rename_cards_ok`) |
| 74 | `_open_extra_dialog` (1281, 19) | `TableFlow` | `_open_extra_dialog` |
| 75 | `_add_dialog_button` (1300, 10) | `TableDialogs` | `add_button(text, id)` |
| 76 | `_rename_cards_ok` (1310, 12) | `TableDialogs` | `rename_cards_ok(new_id)` |
| 77 | `_update_overlays` (1322, 36) | `TablePrompts` | `update_overlays()`; la lista de diálogos "ocupados" pasa a `ctx.dialogs.is_busy()` |
| 78 | `_source_name` (1358, 7) | `TableContext` | `static source_name(pr)` |
| 79 | `_open_prompt` (1365, 62) | `TablePrompts` | `_open_prompt` |
| 80 | `_drink_label` (1427, 5) | `TableContext` | `drink_label()` |
| 81 | `_open_generic_prompt` (1432, 18) | `TablePrompts` | `_open_generic_prompt` |
| 82 | `_start_card_pick` (1450, 8) | `TableFlow` | `start_card_pick()` (lo usan prompts y artefactos) |
| 83 | `_open_choose_card` (1458, 25) | `TablePrompts` | `_open_choose_card` |
| 84 | `_queue_event_notices` (1483, 15) | `TableNotices` | `queue_event_notices(entries)` (lo llama `TableSync`) |
| 85 | `_check_reveals` (1498, 25) | `TableNotices` | `check_reveals()` |
| 86 | `_show_next_notice` (1523, 25) | `TableNotices` | `show_next()` |
| 87 | `_on_notice_ok` (1548, 6) | `TableNotices` | `on_notice_ok`; alias |
| 88 | `pending_notices` (1554, 6) | `TableNotices` | la cáscara conserva `pending_notices()` (reenvía) |
| 89 | `_check_game_over` (1560, 29) | `TableGameOver` | `check()` |
| 90 | `is_game_over_shown` (1589, 2) | `TableGameOver` | la cáscara conserva `is_game_over_shown()` (reenvía) |

Variables de instancia: `demo_when_empty` sigue en la cáscara; `session`, `viewer_id`, `view` pasan a `ctx` y la cáscara las expone como **propiedades** con get/set; `_local_ids`, `_opts`, `_selected`, `_pay_table`, `_flow` (-> `flow_data`), `_pflow`, `_step`, `_shown_prompt_id` -> `ctx`; `_pending_viewer` -> `TableSync`; `_dialog_kind` -> `TableDialogs.kind`; `_warn_prompt_id` -> `TableActions`; `_seen_reveals`, `_notices` -> `TableNotices`; `_game_over_shown` -> `TableGameOver`. Constantes: `Step` -> `TableContext.Step` (alias en la cáscara), `DRINK_PROMPTS` y `FLOW_KINDS_PLAY` -> `TableContext`, `RIVAL_CAP` -> `TablePlayers`.

### 4.1 Orden de construcción (no cambiar)

Hijos de la raíz `VBoxContainer`, en este orden: barra superior (`ctx.menu.build_top_bar()`), `_log`, `ctx.players.build_rival_fan()`, `ctx.center.build()`, `ctx.players.build_own_panel()`, `ctx.hand.build_hint()`, `ctx.actions.build_action_row()`, `ctx.mode_bar.build()`, `ctx.actions.build_drink_button()`, `ctx.hand.build_hand()`.
Hijos directos de la mesa, después del margen y en este orden: `ctx.prompts.build_overlay()` (reacción, z 50), `ctx.dialogs.build_overlay()` (z 50), `ctx.notices.build_overlay()` (z 55), `_toast` (z 60), `_zoom`, `ctx.sync.build_pass_screen()` (z 200). Por último, los 12 módulos `Node`. Cada `build_*()` **devuelve** el `Control` y la cáscara hace el `add_child`.

### 4.2 Orden de `refresh()` (no cambiar)

```
if ctx.view.is_empty(): return
me = ctx.me()
ctx.menu.refresh_turn_label()          # _turn_label
_log.set_entries(...)                  # cáscara
ctx.menu.refresh_rule_button(me)       # _rule_btn.visible
ctx.players.rebuild_rivals()
ctx.center.rebuild()
ctx.players.refresh_own(me)
ctx.actions.refresh_buttons(me)        # termina llamando ctx.mode_bar.refresh()
ctx.hand.refresh_hand(me)
ctx.hand.refresh_hint(me)
ctx.notices.check_reveals()
ctx.prompts.update_overlays()
ctx.notices.show_next()
ctx.game_over.check()
```

### 4.3 Reparto de ids de `PromptDialog` (`on_dialog_button`)

Cada id tiene **un único dueño**. "Cola" = devuelve false y se ejecuta la cola común; "fin" = devuelve true.

| Dueño | Ids | Resultado |
|---|---|---|
| `TableMenu` | `resume` | cola |
| `TableMenu` | `concede`, `menu_exit` (también lo usa el diálogo de fin) | fin |
| `TableGameOver` | `play_again` | fin |
| `TableFlow` | `rule_ok`, `rule_cancel`, `tc_cancel`, `ex_cancel`, `art_cancel`, `art_use`, `tc_ok`, cualquier `ex_<n>` | fin |
| `TableFlow` | `art_zoom` | cola (tras el zoom, como hoy) |
| `TableActions` | `drink_confirm` | fin |
| `TableActions` | `drink_cancel` | cola |
| `TablePrompts` | `p_drink`, `p_drink_free`, `p_decline`, `p_cap`, `cards_ok`, `p_focus`, `p_elixir` | fin |
| `TablePrompts` | `pa_<k>` | fin si `k` es válido; si no, cola |
| `TablePrompts` | `notice_ok` | cola |
| — | cualquier otro | cola |

Un id nuevo lo declara su módulo dueño; `table_dialogs.gd` no se toca para añadir botones.

## 5. API pública y bloque de compatibilidad de la cáscara

Se mantiene en `TableScreen`, con la misma firma:

- Señales `action_requested(action: Dictionary)` y `play_again_requested`.
- `bind_session(p_session: GameSession)` (lo usan `LocalSession`, `UiNav` vía `pending_session`, tests y capturas), `set_view(v, p_viewer := "")`, `options() -> ActionOptions`, `show_toast(text)`, `begin_play(iid, as_react)`, `pending_notices() -> int`, `is_game_over_shown() -> bool`.
- Propiedades `demo_when_empty`, `session`, `viewer_id`, `view`; `const Step = TableContext.Step` (`TableScreen.Step.TARGETS` sigue valiendo).
- `ui_nav.gd` solo usa la ruta de `table.tscn`: sin cambios.

**Bloque de compatibilidad** (al final de la cáscara, `## Compatibilidad: tests y capturas`). Son exactamente los miembros privados que hoy usan `tests/integration/test_local_table.gd`, `local_ui_driver.gd`, `capture_local.gd`, `tests/ui/test_ui_scenes.gd` y `tests/ui/capture.gd`:

- Propiedades de solo lectura (getter) que devuelven el objeto real del módulo o de `ctx`: `_step`, `_selected`, `_pay_table`, `_pflow`, `_dialog`, `_dialog_kind`, `_dialog_overlay`, `_reaction`, `_reaction_overlay`, `_notice_overlay`, `_pass_screen`, `_hint`, `_play_btn`, `_exchange_btn`, `_discard_btn`, `_end_btn`, `_drink_btn`, `_mode_confirm`, `_mode_label`, `_rule_btn`, `_hand`, `_rival_fan`, `_rival_panels`, `_log` (este es real).
- Métodos de una línea: `_me`, `_allowed`, `_flow_targets`, `_reset_flow`, `_on_hand_tapped`, `_on_panel_tapped`, `_on_dialog_button`, `_on_break_rule`, `_on_mode_extra`, `_on_own_card`, `_on_notice_ok`, `_show_zoom`.

Con este bloque **ningún test ni script de captura necesita cambiar**, que es la prueba más fuerte de "sin cambio de comportamiento". V2-13 tiene permiso para adaptar `test_local_table.gd`, `local_ui_driver.gd` y `test_ui_scenes.gd`, pero **no debe hacerlo** salvo que un alias resulte imposible (y lo dirá en su informe). `capture.gd`, `capture_local.gd` y el `capture_v02.gd` de V2-03 no están en su lista de archivos: por eso el bloque es obligatorio. Al empezar, V2-13 ejecuta `grep -rhoE "\bt\.(_[a-z_]+)" tests | sort -u` y añade al bloque cualquier miembro nuevo que haya aparecido (p. ej. por V2-03).

**Convención para tests nuevos** (oleadas 2-4): no usar privados de la cáscara; usar `t.ctx` (getter público de `_ctx`) y los módulos (`t.ctx.hand`, `t.ctx.mode_bar.mode_label`...). El bloque de compatibilidad se congela: no se le añaden miembros después de V2-13.

## 6. Ítem v0.2 -> módulo

| Ítem | Tarea | Archivos de la mesa que edita | Notas |
|---|---|---|---|
| 1 Feedback | V2-22 | `table.gd` (cáscara: crear y conectar `TableFeedback`), `table/table_feedback.gd` (nuevo), `table/table_players.gd` (`panel_for(pid)`, y la actualización incremental de paneles si V2-04 la decide) | Única tarea que edita la cáscara en la oleada 2 |
| 2 Registro | V2-16 | ninguno | Solo `action_log.gd` / `log_text.gd` |
| 3 Jugables + ficha | V2-23 | `table/table_hand.gd` | Resaltado en `refresh_hand`, ficha junto a la pista |
| 4 Pago explícito | V2-24 | `table/table_mode_bar.gd` | Texto en `update()`; preselección en `enter_payment()` |
| 5 Cartas legibles | V2-23 | `table/table_hand.gd` | Botón "Ver" y pista de pulsación larga (misma tarea que el 3) |
| 6 Interfaz honesta | V2-15 | ninguno | Menú y Ajustes |
| 7 Preferencia de reacción | V2-25 | `table/table_prompts.gd` | La decisión de abrir la reacción está en `update_overlays()`; si V2-06 pone el auto-pasar en la sesión, este módulo puede no cambiar |
| 8 Pantalla de fin | V2-26 | `table/table_game_over.gd` | El resumen visual va en `game_over_summary.gd` (nuevo) |
| 9 Bots | V2-17 | ninguno | `src/ai` |
| 10 Contexto y riesgo | V2-29 | `table/table_actions.gd` (color de poción desde límite − 2), `table/table_sync.gd` (motivo de "Pasa el dispositivo"), `table/table_prompts.gd` (pasar "contra ti" a `ReactionPrompt.open`, que hoy no recibe quién mira) | Comparte `table_prompts.gd` con V2-25: ya va después (depende de 25) |
| 11 Ayuda | V2-30 | `table/table_menu.gd` (entrada "Cómo se juega"), `table/table_notices.gd` (duración del evento) | |
| 12 Legibilidad móvil | V2-33 (en solitario) | `table/table_players.gd`, `table_center.gd`, `table_hand.gd`, `table_actions.gd`, `table_mode_bar.gd`, `table_menu.gd`, `table_notices.gd`, `table_dialogs.gd`; la cáscara solo si cambia `_log`/`_toast` | Composición de 5-6 jugadores en `table_players.gd` |

Paralelismo resultante: oleada 2A = V2-22 (cáscara, feedback, players), V2-23 (hand), V2-24 (mode_bar): **sin archivos comunes**. 2B = V2-25 (prompts), V2-26 (game_over): sin comunes. 3A = V2-29 (actions, sync, prompts) y V2-30 (menu, notices): sin comunes.
`table_context.gd` y `table_dialogs.gd` son compartidos: **nadie los edita en las oleadas 2-3**. Un estado nuevo va en el módulo dueño; si de verdad hace falta en `ctx`, se pide en el informe y el Producer abre una mini-tarea en serie (como con la cáscara).

**Cambios para `docs/TAREAS.md` (Producer):** los nombres provisionales cambian así: `table_rivals.gd` -> `table_players.gd`; `table_dialogs.gd` en V2-25 -> `table_prompts.gd`; `table_notices.gd` en V2-26 -> `table_game_over.gd`; `table_flow.gd` en V2-24 -> `table_mode_bar.gd`; `table_flow.gd` en V2-29 -> `table_actions.gd` + `table_sync.gd` + `table_prompts.gd`; V2-22 añade `table/table_feedback.gd`; V2-33 usa la lista del ítem 12. V2-13 crea los 14 archivos de `src/ui/screens/table/` y edita `table.gd`; se espera que **no** edite tests.

## 7. Nota de coordinación con V2-04 (bus de presentación)

`docs/TECNICO/bus-presentacion.md` lo escribe otro agente en paralelo; este documento no lo toca. Puntos de contacto para que ambos encajen:

1. **Enganche:** `TableFeedback` (en `src/ui/screens/table/`) es el consumidor de la mesa; el bus genérico vive en `src/ui/presentation/` (V2-14). La cáscara lo crea y conecta `session.state_changed` **después** de conectar `TableSync.on_state_changed`, para que el feedback se dibuje sobre la vista ya refrescada.
2. **Paneles reconstruidos:** hoy `TablePlayers.rebuild_rivals()` libera y recrea los paneles rivales en cada `refresh()`. Un número flotante hijo de un panel moriría en el siguiente refresco. O el feedback va en una capa propia de la mesa y busca la posición con `ctx.players.panel_for(pid)`, o V2-04 decide la actualización incremental, que se implementa en `table_players.gd` dentro de V2-22 (no en V2-13, que no cambia comportamiento).
3. **Hot-seat:** con la pantalla de paso visible (`ctx.sync`), el feedback debe esperar o filtrarse por `visible_to` según decida V2-04.

## 8. Orden seguro de la refactorización (V2-13)

En cada paso: `bash tools/test.sh` -> **425/425** (o el total vigente, todos en verde) y `bash tools/check_warnings.sh` -> `OK`. Si un paso falla, se arregla antes de seguir; nunca se encadenan dos pasos con rojo.

| Paso | Qué | Verificación extra |
|---|---|---|
| 0 | Línea base: tests y warnings; capturas base (abajo); lista de miembros privados usados por `tests/` (`grep` de §5) | Guardar resultados en el scratchpad |
| 1 | Crear `table_module.gd` y `table_context.gd`. Convertir las variables de estado de la cáscara en **propiedades con get/set que reenvían a `ctx`** (mismo nombre: `_step`, `_selected`, `_flow`...). El resto del código no cambia. Luego mover las consultas puras (fila 13-20, 24-26, 42, 51, 57-59, 67, 71-72, 78, 80) dejando reenvíos | Tests |
| 2 | `TableDialogs` (filas 69, 70, 75, 76, `make_overlay`). Al principio, el `match` actual entero se mueve a la cáscara como un "dueño provisional" de todos los ids; se irá repartiendo en los pasos siguientes | Tests (`test_local_table` recorre casi todos los diálogos) |
| 3 | Módulos hoja de vista: `TableCenter`, `TablePlayers`, `TableMenu` (con `resume`/`concede`/`menu_exit`), `TableNotices`, `TableGameOver` (con `play_again`) | Tests + capturas |
| 4 | `TableHand` y `TableActions` (con `drink_*`) | Tests + capturas (`select`) |
| 5 | `TableFlow` y `TableModeBar` (con `rule_*`, `tc_*`, `ex_*`, `art_*`); `enter_payment()` | Tests (driver de `test_local_table` cubre objetivos, pago, Scroll, Curse of Rules, artefactos) + capturas (`target`) |
| 6 | `TablePrompts` (con `p_*`, `cards_ok`, `pa_*`, `notice_ok`). El dueño provisional del paso 2 debe quedar vacío y se borra | Tests + capturas (`reaction`, `prompt`) |
| 7 | `TableSync` (filas 5-9) | Tests (hot-seat de `test_local_table`, `test_ui_scenes`) + captura (`pass`) |
| 8 | Limpieza: quitar los reenvíos temporales que no estén en el bloque de §5; las propiedades de estado del paso 1 que no estén en §5 desaparecen; mover el bloque de compatibilidad al final | `wc -l src/ui/screens/table.gd src/ui/screens/table/*.gd` (ninguno > 400, cáscara ≤ ~300); `grep -n "TableScreen" src/ui/screens/table/` solo en `table_context.gd`; tests, warnings y todas las capturas |

**Capturas** (necesitan display; sin él, decirlo en el informe y dejar la comparación a QA en V2-21, riesgo R4). Para cada variante, antes (paso 0) y después:
```
/home/brayan/.local/bin/godot --path . -s tests/ui/capture.gd -- table 1080 1920 <dir>/table4.png 4
#   variantes: table 3 / 4 / 6 jugadores; table 4 con extra select, log, zoom, target; reaction; pass; prompt; y 720 1280 para table 4
/home/brayan/.local/bin/godot --path . -s tests/integration/capture_local.gd   # y capture_v02.gd de V2-03 si existe
python3 -I -c "import sys; from PIL import Image, ImageChops; a,b=(Image.open(p).convert('RGB') for p in sys.argv[1:3]); print(ImageChops.difference(a,b).getbbox())" base.png new.png
```
`None` = idénticas. Excepción conocida: la variante `reaction` tiene una barra de tiempo que depende del reloj; ahí se acepta una diferencia limitada a la barra.

**Criterio de hecho de V2-13:** 425 (o más) tests en verde, `check_warnings.sh` OK, ningún archivo de mesa > 400 líneas, tests y scripts de captura sin cambios (o justificados), capturas idénticas (o comparación delegada a QA si no hay display), y en el informe la tabla real de líneas por módulo.

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| Cambiar el orden de llamadas cambia el comportamiento (avisos, diálogos que se pisan) | Órdenes fijos de §4.1 y §4.2; despacho de §4.3 con un dueño por id; pasos pequeños con tests |
| Llamadas antes de `_ready` (`set_view`, `bind_session`) | `ctx` y módulos se crean en `_init()`; los widgets en `_build_ui()` como hoy |
| Copias de arrays que se quedan viejas (`selected` se reasigna) | Regla 6 de §2: siempre leer de `ctx` |
| Referencias cíclicas de clases | Probado en Godot 4.7.2 sin warnings; `ctx` guarda `Node` (no hay ciclo de `RefCounted`) |
| Un módulo crece por encima de 400 en v0.2 | `table_flow.gd` es el más grande (~290); el pago ya está fuera, en `table_mode_bar.gd` |
