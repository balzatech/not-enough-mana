class_name TableActions
extends TableModule
## Fila Jugar / Intercambiar / Descartar / Terminar turno y botón de poción
## (con el aviso de Too Much Mana).

const Step = TableContext.Step
## Separación vertical de la columna de la mesa (table.gd, _build_ui).
const TABLE_SEPARATION: int = 8

var action_row: HBoxContainer
var play_btn: Button
var exchange_btn: Button
var discard_btn: Button
var end_btn: Button
var drink_btn: Button
## Contenedor de Beber poción: deja >= UiTheme.BUTTON_GAP_POTION hasta la fila de acciones.
var drink_box: MarginContainer

var _warn_prompt_id: int = -1


## Fila de acciones del turno: botones principales (UiTheme.apply_primary, 144 a
## 1080) separados UiTheme.BUTTON_GAP_MIN (docs/TAREAS.md §2.1).
func build_action_row() -> HBoxContainer:
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", UiTheme.BUTTON_GAP_MIN)
	play_btn = _action_button("Jugar", _on_play)
	exchange_btn = _action_button("Intercambiar", _on_exchange)
	discard_btn = _action_button("Descartar", _on_discard)
	end_btn = _action_button("Terminar turno", _on_end_turn)
	return action_row


## Beber poción (principal) dentro de un margen: con la separación de la mesa
## (8 px) queda a >= UiTheme.BUTTON_GAP_POTION de la fila de acciones.
func build_drink_button() -> Control:
	drink_btn = UiUtil.button("Beber poción", 44, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(drink_btn)
	drink_btn.add_theme_stylebox_override("normal",
		UiTheme.box(Color(0.12, 0.38, 0.22), 22, UiTheme.COL_POTION, 4, 24, 26))
	drink_btn.add_theme_stylebox_override("pressed",
		UiTheme.box(Color(0.20, 0.52, 0.30), 22, UiTheme.COL_ACCENT, 5, 24, 26))
	drink_btn.add_theme_stylebox_override("hover",
		UiTheme.box(Color(0.16, 0.45, 0.27), 22, UiTheme.COL_POTION, 4, 24, 26))
	drink_btn.pressed.connect(on_drink)
	drink_box = MarginContainer.new()
	drink_box.add_theme_constant_override("margin_top", UiTheme.BUTTON_GAP_POTION - TABLE_SEPARATION)
	drink_box.add_child(drink_btn)
	return drink_box


func _action_button(text: String, cb: Callable) -> Button:
	var b: Button = UiUtil.button(text, 30, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(b)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Con 144 de alto caben dos líneas: "Terminar / turno" sin recortar.
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	action_row.add_child(b)
	return b


## Estado de los botones; termina refrescando la barra de modo.
func refresh_buttons(me: Dictionary) -> void:
	var opts: ActionOptions = ctx.opts
	var acting: bool = ctx.can_act() and ctx.step == Step.NONE
	var n: int = ctx.selected.size()
	var one: int = ctx.selected[0] if n == 1 else -1
	play_btn.disabled = not (acting and n == 1 and not opts.plays_for(one).is_empty())
	exchange_btn.disabled = not (acting and n == 1 and opts.can_exchange(one))
	var xcost: int = ctx.exchange_cost()
	exchange_btn.text = "Intercambiar (%d)" % xcost if xcost >= 0 else "Intercambiar"
	discard_btn.disabled = not (acting and opts.can_discard(ctx.selected))
	end_btn.disabled = not (acting and opts.can_end_turn())
	drink_btn.disabled = not opts.can_drink()
	drink_btn.text = ctx.drink_text(me)
	apply_potion_risk(me)
	action_row.visible = ctx.step == Step.NONE
	ctx.mode_bar.refresh()


## Riesgo de la poción: 0 sin riesgo (o sin límite), 1 desde límite-2,
## 2 en límite-1, 3 si la siguiente poción elimina.
static func potion_risk(drunk: int, limit: int, enabled: bool) -> int:
	if not enabled or limit <= 0:
		return 0
	if drunk >= limit:
		return 3
	if drunk >= limit - 1:
		return 2
	if drunk >= limit - 2:
		return 1
	return 0


const RISK_FILL: Array[Color] = [Color(0.12, 0.38, 0.22), Color(0.42, 0.36, 0.10),
	Color(0.62, 0.30, 0.08), Color(0.45, 0.12, 0.12)]
const RISK_BORDER: Array[Color] = [UiTheme.COL_POTION, Color(0.96, 0.76, 0.26),
	Color(1.0, 0.55, 0.15), UiTheme.COL_DANGER]


## Color + símbolo (⚠) + contador + aviso (tooltip) según el riesgo. No cambia el tamaño.
func apply_potion_risk(me: Dictionary) -> void:
	var cfg: Dictionary = ctx.view.get("config", {}) as Dictionary
	var drunk: int = int(me.get("potions", 0))
	var limit: int = int(cfg.get("potion_limit", 10))
	var lvl: int = potion_risk(drunk, limit, bool(cfg.get("potion_limit_enabled", false)))
	drink_btn.add_theme_stylebox_override("normal", UiTheme.box(RISK_FILL[lvl], 22, RISK_BORDER[lvl], 4, 24, 26))
	if lvl > 0:
		drink_btn.text = "⚠ " + ctx.drink_text(me)
		drink_btn.tooltip_text = "%s\n%s" % [Strings.potion_counter(drunk, limit), Strings.potion_warning(drunk, limit)]
	else:
		drink_btn.tooltip_text = ""
	# La ventana de reacción usa el mismo nivel (QA-V2-32-01).
	if ctx.prompts != null and ctx.prompts.reaction != null:
		ctx.prompts.reaction.set_drink_risk(lvl, drink_btn.tooltip_text)


func on_drink() -> void:
	var pr_id: int = -1
	for pr: Dictionary in ctx.my_prompts():
		if TableContext.DRINK_PROMPTS.has(String(pr["kind"])):
			pr_id = int(pr["id"])
	request_drink(pr_id)


## Bebe (con aviso de Too Much Mana si la poción eliminaría al jugador).
func request_drink(pr_id: int, confirmed: bool = false) -> void:
	if not ctx.opts.can_drink():
		return
	if ctx.drink_would_eliminate() and not confirmed:
		_warn_prompt_id = pr_id
		var cfg: Dictionary = ctx.view.get("config", {}) as Dictionary
		ctx.dialogs.open("drink_warn", "¡Too Much Mana!",
			"Ya has bebido %d pociones. Si bebes otra quedarás eliminado." % int(cfg.get("potion_limit", 10)),
			[{"id": "drink_confirm", "text": "Beber y quedar eliminado"}, {"id": "drink_cancel", "text": "No beber"}])
		return
	var keep_flow: Dictionary = ctx.flow_data
	var keep_step: Step = ctx.step
	var keep_pflow: PlayFlow = ctx.pflow
	var keep_sel: Array[int] = ctx.selected.duplicate()
	var keep_table: Array[int] = ctx.pay_table.duplicate()
	var a: Dictionary = Types.make_action_drink_potion(ctx.viewer_id, pr_id)
	ctx.screen.action_requested.emit(a)
	if ctx.session != null:
		# Beber no interrumpe una jugada a medias (p. ej. para pagar el coste).
		ctx.flow_data = keep_flow
		ctx.step = keep_step
		ctx.pflow = keep_pflow
		ctx.selected = keep_sel
		ctx.pay_table = keep_table
		ctx.dialogs.close()
		ctx.session.submit_action(a)
	elif not ctx.view.is_empty():
		ctx.refresh()


func _on_end_turn() -> void:
	if ctx.opts.can_end_turn():
		ctx.emit_action(Types.make_action_end_turn(ctx.viewer_id))


func _on_exchange() -> void:
	if ctx.selected.size() == 1 and ctx.opts.can_exchange(ctx.selected[0]):
		ctx.emit_action(Types.make_action_exchange(ctx.viewer_id, ctx.selected[0]))


func _on_discard() -> void:
	if ctx.opts.can_discard(ctx.selected):
		ctx.emit_action(Types.make_action_discard(ctx.viewer_id, ctx.selected.duplicate()))


func _on_play() -> void:
	if ctx.selected.size() == 1:
		ctx.flow.begin_play(ctx.selected[0], false)


func on_dialog_button(id: String) -> bool:
	match id:
		"drink_confirm":
			request_drink(_warn_prompt_id, true)
			return true
		"drink_cancel":
			return false
	return false
