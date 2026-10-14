extends RefCounted
## Conductor de pruebas: ejecuta una acción del motor pulsando la mesa
## (TableScreen) como lo haría una persona, y comprueba que la UI emite la
## acción equivalente. Lo usan los tests de integración test_local_*.gd.
##   const Driver = preload("res://tests/integration/local_ui_driver.gd")
##   var drv = Driver.new(table)
##   drv.perform(action)   # true si la UI emitió esa acción

var t: TableScreen
var emitted: Array[Dictionary] = []
var mismatches: Array[String] = []
var performed: Dictionary = {}


func _init(p_table: TableScreen) -> void:
	t = p_table
	t.action_requested.connect(_on_action)


func _on_action(a: Dictionary) -> void:
	emitted.append(a)


## Ejecuta `a` a través de la UI. Si la UI no emite una acción equivalente, la
## registra en `mismatches` y la envía directamente a la sesión (para que la
## partida siga) devolviendo false.
func perform(a: Dictionary) -> bool:
	var before: int = emitted.size()
	_drive(a)
	var ok: bool = false
	for i: int in range(before, emitted.size()):
		if matches(a, emitted[i]):
			ok = true
	var key: String = String(a["type"])
	performed[key] = int(performed.get(key, 0)) + 1
	if not ok:
		var got: String = JSON.stringify(emitted[emitted.size() - 1]) if emitted.size() > before else "nada"
		mismatches.append("%s -> UI emitió %s (step=%d dialog=%s)" % [JSON.stringify(a), got, t._step, t._dialog_kind])
		if t.session != null:
			t._reset_flow()
			t.session.submit_action(a)
	return ok


## Misma acción salvo el texto libre de extra.rule; conjuntos sin orden.
static func matches(want: Dictionary, got: Dictionary) -> bool:
	if String(want["type"]) != String(got.get("type", "")):
		return false
	var w: Dictionary = want.duplicate(true)
	var g: Dictionary = got.duplicate(true)
	for d: Dictionary in [w, g]:
		if d.has("extra"):
			(d["extra"] as Dictionary).erase("rule")
	return ActionOptions.same_action(w, g)


func _hand_card(iid: int) -> Dictionary:
	for c: Variant in t._me().get("hand", []) as Array:
		if int((c as Dictionary)["iid"]) == iid:
			return c as Dictionary
	return {"iid": iid, "card_id": ""}


func _select(cards: Array) -> void:
	t._selected.clear()
	for x: Variant in cards:
		t._on_hand_tapped(_hand_card(int(x)))


func _drive(a: Dictionary) -> void:
	match String(a["type"]):
		Types.ACTION_END_TURN:
			t._end_btn.pressed.emit()
		Types.ACTION_EXCHANGE:
			_select([a["card"]])
			t._exchange_btn.pressed.emit()
		Types.ACTION_DISCARD:
			_select(a["cards"] as Array)
			t._discard_btn.pressed.emit()
		Types.ACTION_DRINK_POTION:
			if int(a["prompt_id"]) >= 0 and t._dialog_overlay.visible and t._dialog_kind == "prompt":
				t._on_dialog_button("p_drink")
			elif t._reaction_overlay.visible:
				t._reaction.drink_requested.emit()
			else:
				t._drink_btn.pressed.emit()
			if t._dialog_kind == "drink_warn":
				t._on_dialog_button("drink_confirm")
		Types.ACTION_PLAY_CARD:
			_select([a["card"]])
			t._play_btn.pressed.emit()
			_complete_flow(a)
		Types.ACTION_REACT:
			t._reaction.react_requested.emit(int(a["card"]))
			_complete_flow(a)
		Types.ACTION_PASS_REACTION:
			if t._reaction_overlay.visible:
				t._reaction.pass_requested.emit()
		Types.ACTION_CHOOSE_TARGETS:
			for x: Variant in a["targets"]:
				if t._step == TableScreen.Step.TARGETS:
					t._on_panel_tapped(String(x))
		Types.ACTION_CHOOSE_CARDS:
			if t._step == TableScreen.Step.CARDS:
				t._selected.clear()
				for x: Variant in a["cards"]:
					t._on_hand_tapped(_hand_card(int(x)))
				t._mode_confirm.pressed.emit()
			elif t._dialog_overlay.visible:
				var chosen: Array[int] = []
				for x: Variant in a["cards"]:
					chosen.append(int(x))
				t._dialog.chosen = chosen
				t._on_dialog_button("cards_ok")
		Types.ACTION_DECLINE:
			if t._dialog_overlay.visible and t._dialog_kind == "prompt":
				t._on_dialog_button("p_decline")
		Types.ACTION_USE_ARTIFACT:
			if int(a["prompt_id"]) >= 0:
				t._on_dialog_button("p_cap")
			else:
				var iid: int = int(a["card"])
				var cid: String = ""
				for c: Variant in t._me().get("artifacts", []) as Array:
					if int((c as Dictionary)["iid"]) == iid:
						cid = String((c as Dictionary)["card_id"])
				t._on_own_card({"iid": iid, "card_id": cid}, UiUtil.card_def(cid))
				t._on_dialog_button("art_use")
				if t._step == TableScreen.Step.CARDS:
					t._selected.clear()
					for x: Variant in a["cards"]:
						t._on_hand_tapped(_hand_card(int(x)))
					t._mode_confirm.pressed.emit()
		Types.ACTION_USE_EVENT:
			var ex: Dictionary = a["extra"]
			if t._dialog.stepper != null:
				t._dialog.stepper.set_value(int(ex.get("mana", ex.get("amount", 0))))
			t._on_dialog_button("p_focus" if ex.has("mana") else "p_elixir")
		Types.ACTION_BREAK_RULE:
			t._on_break_rule()
			t._on_panel_tapped(String(a["target"]))
		Types.ACTION_CONCEDE:
			t._on_dialog_button("concede")


## Completa los pasos de una jugada (objetivos, carta objetivo, opción, pago, regla).
func _complete_flow(a: Dictionary) -> void:
	for _i: int in 16:
		if t._step == TableScreen.Step.TARGETS:
			var chosen: Array[String] = t._flow_targets()
			var tapped: bool = false
			for x: Variant in a["targets"]:
				if not chosen.has(String(x)):
					t._on_panel_tapped(String(x))
					tapped = true
					break
			if not tapped:
				return
		elif t._dialog_overlay.visible and t._dialog_kind == "target_card":
			var tc: Array[int] = [int(a["target_card"])]
			t._dialog.chosen = tc
			t._on_dialog_button("tc_ok")
		elif t._dialog_overlay.visible and t._dialog_kind == "extra":
			var want: Dictionary = (a["extra"] as Dictionary).duplicate(true)
			want.erase("rule")
			var idx: int = t._pflow.extra_choices().find(want)
			t._on_dialog_button("ex_%d" % idx)
		elif t._step == TableScreen.Step.PAYMENT:
			t._selected.clear()
			t._pay_table.clear()
			var hand_ids: Array = []
			for c: Variant in t._me().get("hand", []) as Array:
				hand_ids.append(int((c as Dictionary)["iid"]))
			for x: Variant in a["payment"]:
				if hand_ids.has(int(x)):
					t._on_hand_tapped(_hand_card(int(x)))
				else:
					t._on_mode_extra()
			t._mode_confirm.pressed.emit()
		elif t._dialog_overlay.visible and t._dialog_kind == "rule":
			t._dialog.text_input.text = "No decir sí"
			t._on_dialog_button("rule_ok")
		else:
			return
