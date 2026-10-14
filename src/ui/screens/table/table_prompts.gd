class_name TablePrompts
extends TableModule
## Ventana de reacción y prompts del motor: decide qué superposición se abre y
## cuándo, y atiende los botones de los prompts.

const Step = TableContext.Step

var reaction: ReactionPrompt
var reaction_overlay: Control

## Margen de la ventana con el panel propio y los bordes (px a 1080).
const SHEET_GAP: float = 16.0

var _scrim: ColorRect
var _sheet: ScrollContainer
var _placing: bool = false


func build_overlay() -> Control:
	reaction = ReactionPrompt.new()
	reaction.react_requested.connect(_on_react_card)
	reaction.pass_requested.connect(_on_pass_reaction)
	reaction.drink_requested.connect(ctx.actions.on_drink)
	reaction.card_zoom_requested.connect(ctx.zoom)
	# Hoja inferior bajo el panel propio: vida, maná y pociones siempre visibles (QA-V2-35-04).
	var parts: Array = TableDialogs.make_sheet_overlay(reaction)
	reaction_overlay = parts[0]
	_scrim = parts[1]
	_sheet = parts[2]
	reaction_overlay.resized.connect(place_reaction)
	reaction.minimum_size_changed.connect(place_reaction)
	return reaction_overlay


## Coloca la ventana como hoja inferior: empieza SHEET_GAP px bajo el panel propio
## (vida, maná y pociones siempre a la vista) y llega al borde de la pantalla; si
## no cabe, se desplaza. El escrim deja sin oscurecer el panel propio.
func place_reaction() -> void:
	var ov: Control = reaction_overlay
	var own: Control = ctx.players.own_panel
	if ov == null or not ov.visible or not ov.is_inside_tree() or _placing:
		return
	_placing = true
	var full: Vector2 = ov.size
	var top: float = SHEET_GAP
	var scrim_top: float = 0.0
	if own != null and own.is_visible_in_tree():
		var own_end: float = (ov.get_global_transform().affine_inverse() * own.get_global_rect().end).y
		top = own_end + SHEET_GAP
		scrim_top = own_end + 4.0
	var w: float = full.x - SHEET_GAP * 2.0
	reaction.custom_minimum_size = Vector2(w, 0)
	var h: float = minf(reaction.get_combined_minimum_size().y, maxf(full.y - SHEET_GAP - top, 200.0))
	_sheet.position = Vector2(SHEET_GAP, full.y - SHEET_GAP - h)
	_sheet.size = Vector2(w, h)
	_scrim.position = Vector2(0, scrim_top)
	_scrim.size = Vector2(full.x, maxf(full.y - scrim_top, 0.0))
	_placing = false


func hide_reaction() -> void:
	reaction_overlay.visible = false


func _on_pass_reaction() -> void:
	ctx.emit_action(Types.make_action_pass_reaction(ctx.viewer_id))


func _on_react_card(iid: int) -> void:
	ctx.flow.begin_play(iid, true)


func update_overlays() -> void:
	var dialogs: TableDialogs = ctx.dialogs
	if not ctx.playing():
		reaction_overlay.visible = false
		if dialogs.kind == "prompt":
			dialogs.close()
		return
	var view: Dictionary = ctx.view
	var re: Dictionary = view.get("reaction", {}) as Dictionary
	var mine: bool = not re.is_empty() and Decision.responder(view) == ctx.viewer_id
	var busy_dialog: bool = dialogs.is_busy()
	var picking: bool = ctx.step != Step.NONE or busy_dialog
	reaction_overlay.visible = mine and not picking
	if mine and not picking:
		var hp_mana: String = "Tu vida: %d · Tu maná: %d" % [int(ctx.me().get("hp", 0)), int(ctx.me().get("mana", 0))]
		reaction.set_info(hp_mana)
		reaction.open(re, ctx.me().get("hand", []) as Array, ctx.names(), -1, ctx.opts.reactable_iids(),
			ctx.drink_text(ctx.me()), ctx.opts.can_drink(),
			1 if ReactionRelevance.affects(view, ctx.viewer_id) else 0)
		place_reaction()
		place_reaction.call_deferred()
		return
	if mine:
		return
	var prompts: Array[Dictionary] = ctx.my_prompts()
	if _drop_orphan_flow(prompts):
		return
	if prompts.is_empty():
		ctx.shown_prompt_id = -1
		if dialogs.kind == "prompt" and dialogs.is_open():
			dialogs.close()
		return
	var pr: Dictionary = prompts[0]
	var pid: int = int(pr["id"])
	if pid == ctx.shown_prompt_id and (picking or dialogs.is_open()):
		return
	if busy_dialog or (dialogs.is_open() and dialogs.kind != "prompt" and dialogs.kind != ""):
		return
	ctx.shown_prompt_id = pid
	_open_prompt(pr)


## Una elección atada a un prompt (descarte, objetivos) que ya no está pendiente
## (lo resolvió la sesión, el plazo o un auto-pase) deja la mesa en modo huérfano:
## se cancela. Las jugadas del jugador (sin prompt_id) no se tocan.
func _drop_orphan_flow(prompts: Array[Dictionary]) -> bool:
	if not ctx.flow_data.has("prompt_id"):
		return false
	var pid: int = int(ctx.flow_data["prompt_id"])
	for pr: Dictionary in prompts:
		if int(pr["id"]) == pid:
			return false
	ctx.reset_flow()
	ctx.shown_prompt_id = -1
	ctx.refresh()
	return true


func _open_prompt(pr: Dictionary) -> void:
	var data: Dictionary = pr.get("data", {}) as Dictionary
	var pid: int = int(pr["id"])
	var src: String = TableContext.source_name(pr)
	var me: Dictionary = ctx.me()
	var potions: String = ctx.drink_text(me).replace("Beber poción  ", "Pociones bebidas: ")
	match String(pr["kind"]):
		Types.PROMPT_DISCARD:
			var hand_n: int = (me.get("hand", []) as Array).size()
			var need_n: int = mini(int(data.get("count", 1)), hand_n)
			ctx.flow_data = {"kind": "choose_cards", "prompt_id": pid, "card": -1, "need_cards": need_n,
				"title": "Descarta %s%s" % [Strings.cards(need_n), (" (" + src + ")") if src != "" else ""]}
			ctx.flow.start_card_pick()
		Types.PROMPT_CHOOSE_CARD:
			_open_choose_card(pr)
		Types.PROMPT_CHOOSE_TARGETS:
			var allowed: Array[String] = []
			for a: Variant in data.get("allowed", []) as Array:
				allowed.append(String(a))
			ctx.flow_data = {"kind": "choose_targets", "prompt_id": pid, "card": -1,
				"need_targets": int(data.get("count", 1)), "allowed": allowed,
				"targets": [] as Array[String], "title": ("%s: elige objetivo" % src) if src != "" else ""}
			ctx.flow.advance()
		Types.PROMPT_MANA_SHORTFALL:
			ctx.dialogs.open("prompt", "Maná insuficiente",
				"Te faltan %d de maná. Bebe pociones o pierde esa vida.\n%s" % [int(data.get("missing", 0)), potions],
				[{"id": "p_drink", "text": ctx.drink_label()},
				{"id": "p_decline", "text": "Perder %d de vida" % int(data.get("missing", 0))}])
		Types.PROMPT_DRINK_OR_SUFFER:
			ctx.dialogs.open("prompt", "Visit of the Archmage",
				"Bebe una poción o pierde %d de vida.\n%s" % [int(data.get("hp", 1)), potions],
				[{"id": "p_drink", "text": ctx.drink_label()}, {"id": "p_decline", "text": "Perder vida"}])
		Types.PROMPT_USE_MAGIC_CAP:
			var loss: Dictionary = data.get("loss", {}) as Dictionary
			var what: String = "%d de %s" % [int(loss.get("amount", 0)),
				"maná" if String(loss.get("kind", "")) == Damage.KIND_MANA_LOSS else "vida"]
			ctx.dialogs.open("prompt", "Magic Cap", "Vas a perder %s. ¿Descartas el gorro para evitarlo?" % what,
				[{"id": "p_cap", "text": "Usar Magic Cap"}, {"id": "p_decline", "text": "No usar"}])
		Types.PROMPT_MANA_FOCUS:
			var dmg: int = int(data.get("damage", 0))
			var top: int = mini(dmg, int(me.get("mana", 0)))
			ctx.dialogs.open("prompt", "Mana Focus",
				"Vas a recibir %d de daño. Elige cuánto maná gastas para evitarlo (1 maná = 1 de daño)." % dmg,
				[{"id": "p_focus", "text": "Confirmar"}, {"id": "p_decline", "text": "No usar"}], top)
		Types.PROMPT_ELIXIR_TRANSMUTATION:
			var top_n: int = 0
			for a: Variant in ctx.opts.prompt_actions(pid, Types.ACTION_USE_EVENT):
				top_n = maxi(top_n, int(((a as Dictionary)["extra"] as Dictionary).get("amount", 0)))
			var price: int = int(data.get("price", 2))
			var buttons: Array = []
			if top_n > 0:
				buttons.append({"id": "p_elixir", "text": "Comprar vida"})
			buttons.append({"id": "p_drink_free", "text": ctx.drink_label()})
			buttons.append({"id": "p_decline", "text": "No comprar"})
			var msg: String = "Compra vida a %d de maná cada punto." % price
			if top_n <= 0:
				msg += " Ahora no te llega el maná: puedes beber antes."
			ctx.dialogs.open("prompt", "Elixir Transmutation", msg, buttons, top_n if top_n > 0 else -1, false, "",
				1 if top_n > 0 else 0)
		_:
			_open_generic_prompt(pr)


## Prompt sin pantalla propia: un botón por acción legal.
func _open_generic_prompt(pr: Dictionary) -> void:
	var buttons: Array = []
	var acts: Array = ctx.opts.prompt_actions(int(pr["id"]))
	for k: int in acts.size():
		var a: Dictionary = acts[k]
		var txt: String = String(a["type"]).capitalize()
		match String(a["type"]):
			Types.ACTION_DECLINE:
				txt = "Rechazar"
			Types.ACTION_DRINK_POTION:
				txt = "Beber poción"
		buttons.append({"id": "pa_%d" % k, "text": txt})
	if buttons.is_empty():
		buttons.append({"id": "notice_ok", "text": "Entendido"})
	var src: String = TableContext.source_name(pr)
	ctx.dialogs.open("prompt", src if src != "" else "Decisión", "Elige una opción.", buttons)


## Magic Hand y similares: elegir una carta de la mano revelada de otro mago
## (vista privada: solo la ve quien lanzó la carta).
func _open_choose_card(pr: Dictionary) -> void:
	var data: Dictionary = pr.get("data", {}) as Dictionary
	var from: String = String(data.get("from", ""))
	var known: Dictionary = {}
	for c: Variant in ActionOptions.revealed_hand(ctx.view, ctx.viewer_id, from):
		known[int((c as Dictionary)["iid"])] = c
	var cards: Array = []
	var ids: Array = data.get("cards", []) as Array
	if ids.is_empty():
		for k: Variant in known:
			cards.append(known[k])
	else:
		for iid: Variant in ids:
			cards.append(known.get(int(iid), {"iid": int(iid), "card_id": ""}))
	var src: String = TableContext.source_name(pr)
	ctx.dialogs.open_cards("prompt", src if src != "" else "Elige una carta",
		"Mano de %s (solo la ves tú). Toca la carta que te quedas." % TableContext.name_of(ctx.view, from), cards,
		int(data.get("count", 1)))
	ctx.dialogs.show_overlay()


func on_dialog_button(id: String) -> bool:
	var viewer: String = ctx.viewer_id
	var pr_id: int = ctx.shown_prompt_id
	match id:
		"notice_ok":
			return false
		"p_drink":
			ctx.actions.request_drink(pr_id)
			return true
		"p_drink_free":
			ctx.actions.request_drink(-1)
			return true
		"p_decline":
			ctx.emit_action(Types.make_action_decline(viewer, pr_id))
			return true
		"p_cap":
			var cap_actions: Array = ctx.opts.prompt_actions(pr_id, Types.ACTION_USE_ARTIFACT)
			if not cap_actions.is_empty():
				ctx.emit_action(cap_actions[0] as Dictionary)
				return true
			var cap: int = ctx.find_my_artifact(Types.CARD_MAGIC_CAP)
			ctx.emit_action(Types.make_action_use_artifact(viewer, cap, [], [], {}, pr_id))
			return true
		"cards_ok":
			var chosen: Array = []
			for x: int in ctx.dialogs.chosen():
				chosen.append(x)
			ctx.emit_action(Types.make_action_choose_cards(viewer, pr_id, chosen))
			return true
		"p_focus":
			var amount: int = ctx.dialogs.stepper_value(0)
			ctx.emit_action(Types.make_action_use_event(viewer, {"mana": amount}, pr_id))
			return true
		"p_elixir":
			var n: int = ctx.dialogs.stepper_value(1)
			ctx.emit_action(Types.make_action_use_event(viewer, {"amount": n}, pr_id))
			return true
	if id.begins_with("pa_"):
		var k: int = int(id.substr(3))
		var acts: Array = ctx.opts.prompt_actions(pr_id)
		if k >= 0 and k < acts.size():
			ctx.emit_action(acts[k] as Dictionary)
			return true
	return false
