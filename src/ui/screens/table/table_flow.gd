class_name TableFlow
extends TableModule
## Máquina de jugada: objetivos, carta objetivo, opción extra, texto de Curse of
## Rules, elección de cartas y artefactos. Las jugadas se construyen con
## PlayFlow (objetivos -> carta objetivo -> opción -> pago -> regla) y se envían
## con ctx.emit_action. El pago lo lleva TableModeBar.

const Step = TableContext.Step


## Inicia la jugada de una carta (o respuesta): objetivos, carta objetivo,
## opción, pago y texto de Curse of Rules; luego envía la acción.
func begin_play(iid: int, as_react: bool) -> void:
	var inst: Dictionary = ctx.find_in_hand(iid)
	if inst.is_empty():
		return
	var cands: Array = ctx.opts.reacts_for(iid) if as_react else ctx.opts.plays_for(iid)
	if cands.is_empty():
		var why: String = ctx.hand.unplayable_reason(inst) if not as_react \
			else "No puedes responder con esa carta ahora."
		ctx.toast(why if why != "" else "No se puede jugar ahora.")
		return
	var def: Dictionary = UiUtil.card_def(String(inst["card_id"]))
	ctx.pflow = PlayFlow.create(cands)
	ctx.flow_data = {"kind": "react" if as_react else "play", "card": iid, "def": def,
		"payment_done": false, "rule_done": String(inst["card_id"]) != Types.CARD_CURSE_OF_RULES}
	ctx.selected.clear()
	ctx.pay_table.clear()
	advance()


func advance() -> void:
	var flow: Dictionary = ctx.flow_data
	var kind: String = String(flow.get("kind", ""))
	if TableContext.FLOW_KINDS_PLAY.has(kind):
		_advance_play()
		return
	var targets: Array = flow.get("targets", [])
	if targets.size() < int(flow.get("need_targets", 0)):
		ctx.step = Step.TARGETS
		ctx.prompts.hide_reaction()
		ctx.refresh()
		return
	ctx.step = Step.NONE
	if kind == "break_rule":
		ctx.emit_action(Types.make_action_break_rule(ctx.viewer_id, String(targets[0]), int(flow["card"])))
	elif kind == "choose_targets":
		ctx.emit_action(Types.make_action_choose_targets(ctx.viewer_id, int(flow["prompt_id"]),
			targets.duplicate()))


func _advance_play() -> void:
	var pflow: PlayFlow = ctx.pflow
	if not pflow.targets_done():
		ctx.step = Step.TARGETS
		ctx.prompts.hide_reaction()
		ctx.refresh()
		return
	if pflow.needs_target_card():
		ctx.step = Step.NONE
		_open_target_card_dialog()
		return
	if pflow.needs_extra():
		ctx.step = Step.NONE
		_open_extra_dialog()
		return
	if pflow.needs_payment() and not bool(ctx.flow_data.get("payment_done", false)):
		ctx.mode_bar.enter_payment()
		return
	if not bool(ctx.flow_data.get("rule_done", true)):
		ctx.step = Step.NONE
		_open_rule_dialog("Escribe la regla que deberán cumplir todos.")
		return
	var extra: Dictionary = {}
	if ctx.flow_data.has("rule"):
		extra["rule"] = String(ctx.flow_data["rule"])
	var a: Dictionary = pflow.build(ctx.flow_data.get("payment", []) as Array, extra)
	if a.is_empty():
		ctx.toast("Esa jugada no es válida.")
		cancel()
		return
	ctx.emit_action(a)


func _open_rule_dialog(message: String) -> void:
	ctx.dialogs.open("rule", "Curse of Rules", message,
		[{"id": "rule_ok", "text": "Lanzar maldición"}, {"id": "rule_cancel", "text": "Cancelar"}],
		-1, true, "Ej.: no decir 'sí'")


## Elección de cartas de la mano (descarte forzado, Transformation Glove...).
func advance_cards() -> void:
	var kind: String = String(ctx.flow_data.get("kind", ""))
	var chosen: Array = []
	for x: int in ctx.selected:
		chosen.append(x)
	if kind == "choose_cards":
		var pr_id: int = int(ctx.flow_data["prompt_id"])
		var a: Dictionary = Types.make_action_choose_cards(ctx.viewer_id, pr_id, chosen)
		if not ctx.opts.contains(a):
			ctx.toast(UiUtil.error_text(Types.ERR_INVALID_CHOICE))
			return
		ctx.emit_action(a)
	elif kind == "artifact_cards":
		ctx.emit_action(Types.make_action_use_artifact(ctx.viewer_id, int(ctx.flow_data["card"]), [], chosen))


func cancel() -> void:
	ctx.reset_flow()
	ctx.shown_prompt_id = -1
	ctx.refresh()


func start_card_pick() -> void:
	ctx.step = Step.CARDS
	ctx.selected.clear()
	ctx.refresh()


func on_panel_tapped(pid: String) -> void:
	if ctx.step != Step.TARGETS or not ctx.allowed().has(pid):
		return
	var flow: Dictionary = ctx.flow_data
	if ctx.pflow != null and TableContext.FLOW_KINDS_PLAY.has(String(flow.get("kind", ""))):
		if not ctx.pflow.toggle_target(pid):
			return
		if ctx.pflow.targets_done():
			advance()
		else:
			ctx.refresh()
		return
	var targets: Array = flow["targets"]
	if targets.has(pid):
		targets.erase(pid)
	elif int(flow["need_targets"]) == 1:
		targets.clear()
		targets.append(pid)
	else:
		targets.append(pid)
	if targets.size() >= int(flow["need_targets"]):
		advance()
	else:
		ctx.refresh()


## Toque en una carta de mi panel: si es un artefacto usable, ofrece usarlo.
func on_own_card(card: Dictionary, def: Dictionary) -> void:
	var iid: int = int(card.get("iid", -1))
	if ctx.step == Step.NONE and not ctx.opts.artifact_uses(iid).is_empty():
		ctx.flow_data = {"kind": "artifact", "card": iid, "card_id": String(card.get("card_id", ""))}
		ctx.dialogs.open("artifact", String(def.get("name", "Artefacto")), "¿Quieres usarlo ahora?",
			[{"id": "art_use", "text": "Usar"}, {"id": "art_zoom", "text": "Ver carta"},
			{"id": "art_cancel", "text": "Cancelar"}])
		return
	ctx.zoom(card, def)


func _use_artifact(iid: int) -> void:
	var uses: Array = ctx.opts.artifact_uses(iid)
	if uses.is_empty():
		return
	var first: Dictionary = uses[0]
	if (first.get("cards", []) as Array).is_empty():
		ctx.emit_action(first)
		return
	# Transformation Glove: elegir la carta de la mano que se cambia.
	var pool: Array = []
	for a: Variant in uses:
		for x: Variant in (a as Dictionary)["cards"]:
			if not pool.has(int(x)):
				pool.append(int(x))
	ctx.flow_data = {"kind": "artifact_cards", "card": iid, "need_cards": 1, "pool": pool,
		"title": "Elige la carta que quieres cambiar", "cancellable": true}
	start_card_pick()


func _open_target_card_dialog() -> void:
	var cards: Array = []
	for iid: int in ctx.pflow.target_card_choices():
		cards.append(ctx.card_in_play(iid))
	ctx.prompts.hide_reaction()
	ctx.dialogs.open_cards("target_card", "Elige la carta", "Toca la carta en juego que quieres anular.", cards, 1)
	ctx.dialogs.add_button("Cancelar", "tc_cancel")
	ctx.dialogs.rename_cards_ok("tc_ok")
	ctx.dialogs.show_overlay()


func _open_extra_dialog() -> void:
	var buttons: Array = []
	var choices: Array[Dictionary] = ctx.pflow.extra_choices()
	var names: Dictionary = ctx.names()
	var def: Dictionary = ctx.flow_data.get("def", {}) as Dictionary
	for i: int in choices.size():
		var ex: Dictionary = choices[i]
		var txt: String = "Opción %d" % (i + 1)
		if ex.has("protect"):
			txt = "Proteger a %s" % String(names.get(String(ex["protect"]), String(ex["protect"])))
		elif ex.is_empty():
			txt = "Protegerte a ti" if String(def.get("id", "")) == Types.CARD_MIRROR_SHIELD else "Opción normal"
		buttons.append({"id": "ex_%d" % i, "text": txt})
	buttons.append({"id": "ex_cancel", "text": "Cancelar"})
	ctx.prompts.hide_reaction()
	ctx.dialogs.open("extra", String(def.get("name", "")), "Elige una opción.", buttons)


func on_dialog_button(id: String) -> bool:
	match id:
		"rule_ok":
			var txt: String = ctx.dialogs.text_value()
			if txt == "":
				_open_rule_dialog("La regla no puede quedar vacía. Escríbela.")
				return true
			ctx.flow_data["rule"] = txt
			ctx.flow_data["rule_done"] = true
			advance()
			return true
		"rule_cancel", "tc_cancel", "ex_cancel", "art_cancel":
			cancel()
			return true
		"art_use":
			_use_artifact(int(ctx.flow_data.get("card", -1)))
			return true
		"art_zoom":
			var iid: int = int(ctx.flow_data.get("card", -1))
			var cid: String = String(ctx.flow_data.get("card_id", ""))
			ctx.reset_flow()
			ctx.zoom({"iid": iid, "card_id": cid}, UiUtil.card_def(cid))
			return false
		"tc_ok":
			var chosen: Array[int] = ctx.dialogs.chosen()
			if chosen.size() == 1 and ctx.pflow != null:
				ctx.pflow.choose_target_card(chosen[0])
				advance()
				return true
			cancel()
			return true
	if id.begins_with("ex_"):
		var idx: int = int(id.substr(3))
		var choices: Array[Dictionary] = ctx.pflow.extra_choices() if ctx.pflow != null else []
		if idx >= 0 and idx < choices.size():
			ctx.pflow.choose_extra(choices[idx])
			advance()
			return true
		cancel()
		return true
	return false
