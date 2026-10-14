class_name TableModeBar
extends TableModule
## Barra de modo (objetivos, pago y elección de cartas): texto, Confirmar,
## Usar/Quitar Scroll y Cancelar. Atiende los toques de la mano en PAYMENT y CARDS.

const Step = TableContext.Step

var bar: VBoxContainer
var mode_label: Label
var mode_confirm: Button
var mode_cancel: Button
var mode_extra: Button


func build() -> VBoxContainer:
	bar = VBoxContainer.new()
	bar.visible = false
	mode_label = UiUtil.label("", 28, UiTheme.COL_ACCENT)
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(mode_label)
	# Confirmar es principal (144 a 1080); Usar Scroll y Cancelar, secundarios.
	# En una fila, todos toman el alto de Confirmar (docs/TAREAS.md §2.1).
	var mode_row: HBoxContainer = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", UiTheme.BUTTON_GAP_MIN)
	mode_extra = UiUtil.button("Usar Scroll", 28, UiTheme.BUTTON_MIN_H)
	mode_extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_extra.pressed.connect(on_mode_extra)
	mode_row.add_child(mode_extra)
	mode_confirm = UiUtil.button("Confirmar", 32, UiTheme.BUTTON_PRIMARY_H)
	mode_confirm.custom_minimum_size = Vector2(230, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(mode_confirm)
	mode_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_confirm.pressed.connect(_on_mode_confirm)
	mode_row.add_child(mode_confirm)
	mode_cancel = UiUtil.button("Cancelar", 28, UiTheme.BUTTON_MIN_H)
	mode_cancel.custom_minimum_size = Vector2(210, UiTheme.BUTTON_MIN_H)
	mode_cancel.pressed.connect(ctx.flow.cancel)
	mode_row.add_child(mode_cancel)
	bar.add_child(mode_row)
	return bar


## Visibilidad de la barra según el paso de la jugada (la llama TableActions).
func refresh() -> void:
	bar.visible = ctx.step != Step.NONE
	if ctx.step != Step.NONE:
		update()


## Entra en el paso de pago de la jugada en curso.
func enter_payment() -> void:
	ctx.step = Step.PAYMENT
	ctx.selected.clear()
	ctx.pay_table.clear()
	if ctx.pflow != null:
		var sole: Array = ctx.pflow.sole_payment()
		var hand_ids: Array = _hand_ids()
		for x: Variant in sole:
			if hand_ids.has(int(x)):
				ctx.selected.append(int(x))
			else:
				ctx.pay_table.append(int(x))
	ctx.prompts.hide_reaction()
	ctx.refresh()


func update() -> void:
	var flow: Dictionary = ctx.flow_data
	var pflow: PlayFlow = ctx.pflow
	var kind: String = String(flow.get("kind", ""))
	mode_cancel.visible = not kind.begins_with("choose") or bool(flow.get("cancellable", false))
	mode_extra.visible = false
	var card_name: String = String((flow.get("def", {}) as Dictionary).get("name", ""))
	match ctx.step:
		Step.TARGETS:
			var need: int = pflow.need_targets() if pflow != null and TableContext.FLOW_KINDS_PLAY.has(kind) \
				else int(flow.get("need_targets", 1))
			var title: String = String(flow.get("title", ""))
			if title == "":
				title = ("%s: elige objetivo" % card_name) if card_name != "" else "Elige objetivo"
			mode_label.text = "%s (%d/%d)" % [title, ctx.flow_targets().size(), need]
			mode_confirm.visible = false
		Step.PAYMENT:
			var pay: Array = ctx.payment()
			var def: Dictionary = flow.get("def", {}) as Dictionary
			var reqs: Array = (def.get("cost", {}) as Dictionary).get("cards", []) as Array
			var needp: int = Strings.requirement_total(reqs)
			var req_text: String = pflow.requirement_for(def, _hand_ids()) if pflow != null else ""
			if pflow != null and needp == 0:
				needp = pflow.payment_size()
			if req_text == "":
				req_text = Strings.cards(needp)
			mode_label.text = Strings.pay_header(card_name, req_text, pay.size(), needp)
			mode_confirm.visible = true
			mode_confirm.disabled = pflow == null or not pflow.payment_valid(pay)
			var wild: Array[int] = _wildcards_available()
			if not wild.is_empty() or not ctx.pay_table.is_empty():
				mode_extra.visible = true
				mode_extra.text = "Quitar Scroll" if not ctx.pay_table.is_empty() else "Usar Scroll"
		Step.CARDS:
			var needc: int = int(flow.get("need_cards", 1))
			mode_label.text = "%s (%d/%d)" % [String(flow.get("title", "Elige cartas")), ctx.selected.size(), needc]
			mode_confirm.visible = true
			mode_confirm.disabled = ctx.selected.size() != needc


func _hand_ids() -> Array:
	var out: Array = []
	for c: Variant in ctx.me().get("hand", []) as Array:
		out.append(int((c as Dictionary)["iid"]))
	return out


## Comodines en mesa (Scroll of Elements) que pueden entrar en el pago actual.
func _wildcards_available() -> Array[int]:
	var out: Array[int] = []
	if ctx.pflow == null:
		return out
	var hand_ids: Array = []
	for c: Variant in ctx.me().get("hand", []) as Array:
		hand_ids.append(int((c as Dictionary)["iid"]))
	for iid: int in ctx.pflow.payment_choices(ctx.payment()):
		if not hand_ids.has(iid):
			out.append(iid)
	return out


func on_mode_extra() -> void:
	if ctx.step != Step.PAYMENT:
		return
	if not ctx.pay_table.is_empty():
		ctx.pay_table.clear()
	else:
		var wild: Array[int] = _wildcards_available()
		if wild.is_empty():
			ctx.toast("El comodín no sirve para este pago.")
			return
		ctx.pay_table.append(wild[0])
	ctx.hand.refresh_hand(ctx.me())
	update()


func _on_mode_confirm() -> void:
	if ctx.step == Step.PAYMENT:
		var pay: Array = ctx.payment()
		if ctx.pflow == null or not ctx.pflow.payment_valid(pay):
			ctx.toast(UiUtil.error_text(Types.ERR_INVALID_PAYMENT))
			return
		ctx.flow_data["payment"] = pay
		ctx.flow_data["payment_done"] = true
		ctx.selected.clear()
		ctx.pay_table.clear()
		ctx.step = Step.NONE
		ctx.flow.advance()
	elif ctx.step == Step.CARDS:
		ctx.flow.advance_cards()


## Toque en una carta de la mano durante el pago o la elección de cartas.
func on_hand_tapped(iid: int) -> void:
	if ctx.step == Step.PAYMENT:
		if iid == int(ctx.flow_data.get("card", -1)):
			return
		if ctx.selected.has(iid):
			ctx.selected.erase(iid)
		elif ctx.pflow != null and ctx.pflow.payment_choices(ctx.payment()).has(iid):
			ctx.selected.append(iid)
		else:
			ctx.toast("Esa carta no sirve para pagar.")
			return
		ctx.hand.refresh_hand(ctx.me())
		update()
		return
	if ctx.step == Step.CARDS:
		var pool: Array = ctx.flow_data.get("pool", []) as Array
		if not pool.is_empty() and not pool.has(iid):
			return
		if ctx.selected.has(iid):
			ctx.selected.erase(iid)
		elif ctx.selected.size() < int(ctx.flow_data.get("need_cards", 1)):
			ctx.selected.append(iid)
		elif int(ctx.flow_data.get("need_cards", 1)) == 1:
			ctx.selected = [iid] as Array[int]
		ctx.hand.refresh_hand(ctx.me())
		update()
