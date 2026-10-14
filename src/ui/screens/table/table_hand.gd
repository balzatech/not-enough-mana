class_name TableHand
extends TableModule
## Mano del que mira: selección normal, pista bajo el panel y motivo de
## "no jugable". En pago o elección de cartas los toques los atiende TableModeBar.

const Step = TableContext.Step

## Alto mínimo de la mano: con 6 jugadores y la ficha abierta la mesa entera cabe
## en 1920 (V2-33); con espacio libre la mano crece (cartas hasta 420 de alto).
const HAND_MIN_H: float = 260.0

var hint: Label
var hand_view: HandView
var info: CardInfo
var infos: Dictionary = {}
## Reserva el hueco de la ficha en mi turno para que la mesa no salte al seleccionar.
var _gap: Control


func build_hint() -> Label:
	hint = UiUtil.label("", 26, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.visible = false
	return hint


## Contenedor: ficha de la carta seleccionada + la mano.
func build_hand() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info = CardInfo.new()
	# El motivo de "no jugable" ya va en la pista bajo el panel: la ficha no lo repite (QA-V2-27-03).
	info.show_reason = false
	info.view_requested.connect(ctx.zoom)
	box.add_child(info)
	_gap = Control.new()
	_gap.custom_minimum_size = Vector2(0, 118)
	_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gap.visible = false
	box.add_child(_gap)
	box.add_child(_build_hand_view())
	return box


func _build_hand_view() -> HandView:
	hand_view = HandView.new()
	hand_view.custom_minimum_size = Vector2(0, HAND_MIN_H)
	hand_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_view.card_tapped.connect(on_hand_tapped)
	hand_view.card_zoom_requested.connect(ctx.zoom)
	return hand_view


func refresh_hand(me: Dictionary) -> void:
	var cards: Array = me.get("hand", []) as Array
	var interactive: bool = ctx.can_act() or ctx.step == Step.PAYMENT or ctx.step == Step.CARDS
	var disabled: Array[int] = []
	var hand_ids: Array[int] = []
	for c: Variant in cards:
		hand_ids.append(int((c as Dictionary)["iid"]))
	if ctx.step == Step.PAYMENT and ctx.pflow != null:
		var choices: Array[int] = ctx.pflow.payment_choices(ctx.payment())
		for iid: int in hand_ids:
			if not ctx.selected.has(iid) and not choices.has(iid):
				disabled.append(iid)
	elif ctx.step == Step.CARDS:
		var pool: Array = ctx.flow_data.get("pool", []) as Array
		if not pool.is_empty():
			for iid: int in hand_ids:
				if not pool.has(iid):
					disabled.append(iid)
	elif ctx.step == Step.TARGETS:
		interactive = false
	var valid: Array[int] = []
	for iid: int in ctx.selected:
		if hand_ids.has(iid):
			valid.append(iid)
	ctx.selected = valid
	var playable: Dictionary = {}
	infos = {}
	if ctx.playing() and not me.is_empty() and not bool(me.get("eliminated", false)):
		infos = CardInfo.for_hand(ctx.view, ctx.viewer_id, ctx.opts)
		if ctx.can_act() and ctx.step == Step.NONE:
			for iid: Variant in infos:
				playable[iid] = bool((infos[iid] as Dictionary)["playable"])
	hand_view.set_hand(cards, ctx.selected, interactive, disabled, playable)
	_refresh_info()


## Ficha: solo con una carta seleccionada en el turno propio y sin flujo en curso.
func _refresh_info() -> void:
	if info == null:
		return
	if ctx.can_act() and ctx.step == Step.NONE and ctx.selected.size() == 1 \
			and infos.has(ctx.selected[0]):
		info.show_info(infos[ctx.selected[0]] as Dictionary, ctx.find_in_hand(ctx.selected[0]))
	else:
		info.clear()
	_gap.visible = not info.visible and ctx.can_act() and ctx.step == Step.NONE


func refresh_hint(me: Dictionary) -> void:
	var txt: String = ""
	if not ctx.playing() or me.is_empty():
		txt = ""
	elif bool(me.get("eliminated", false)):
		txt = "Has quedado eliminado. Puedes seguir mirando la partida."
	elif ctx.step != Step.NONE:
		txt = ""
	elif ctx.can_act() and ctx.selected.size() == 1 and ctx.opts.plays_for(ctx.selected[0]).is_empty():
		txt = unplayable_reason(ctx.find_in_hand(ctx.selected[0]))
	elif not ctx.can_act():
		var d: String = Decision.decider(ctx.view)
		var names: Dictionary = ctx.names()
		if d != "" and d != ctx.viewer_id:
			var what: String = "reacción" if Decision.responder(ctx.view) == d else (
				"decisión" if not (ctx.view.get("pending", []) as Array).is_empty() else "turno")
			txt = "Esperando a %s (%s)…" % [String(names.get(d, d)), what]
	elif not ctx.opts.usable_artifacts().is_empty():
		txt = "Puedes usar un artefacto: tócalo en tu panel."
	hint.text = txt
	hint.visible = txt != ""


## Explicación en español de por qué no se puede jugar una carta.
func unplayable_reason(inst: Dictionary) -> String:
	if inst.is_empty():
		return ""
	var card_id: String = String(inst.get("card_id", ""))
	var def: Dictionary = CardCatalog.get_def(card_id)
	if def.is_empty():
		def = UiUtil.card_def(card_id)
	var nm: String = String(def.get("name", card_id))
	var t: String = String(def.get("type", ""))
	if t == Types.CARD_TYPE_DEFENSIVE:
		return "%s es defensiva: se juega como respuesta a un hechizo." % nm
	if t == Types.CARD_TYPE_EVENT or t == Types.CARD_TYPE_NON_PLAYABLE or not bool(def.get("playable", true)):
		return "%s no se puede jugar." % nm
	var flags: Dictionary = ctx.me().get("flags", {}) as Dictionary
	if t == Types.CARD_TYPE_OFFENSIVE and bool(flags.get("blinded", false)):
		return "Estás cegado: no puedes lanzar ofensivas."
	var cost: int = Damage.card_cost(ctx.view, ctx.viewer_id, def, int(inst.get("iid", -1)), false)
	var mana: int = int(ctx.me().get("mana", 0))
	if mana < cost:
		return "%s cuesta %d de maná y tienes %d. Bebe una poción." % [nm, cost, mana]
	if not ((def.get("cost", {}) as Dictionary).get("cards", []) as Array).is_empty():
		return "%s: no tienes cartas que sirvan para pagar su coste." % nm
	return "%s no tiene ahora ningún objetivo válido." % nm


func on_hand_tapped(card: Dictionary) -> void:
	var iid: int = int(card["iid"])
	if ctx.step == Step.PAYMENT or ctx.step == Step.CARDS:
		ctx.mode_bar.on_hand_tapped(iid)
		return
	if not ctx.can_act() or ctx.step != Step.NONE:
		return
	if ctx.selected.has(iid):
		ctx.selected.erase(iid)
	else:
		ctx.selected.append(iid)
	refresh_hand(ctx.me())
	ctx.actions.refresh_buttons(ctx.me())
	refresh_hint(ctx.me())
