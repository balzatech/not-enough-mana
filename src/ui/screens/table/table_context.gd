class_name TableContext
extends RefCounted
## Estado compartido de la mesa, consultas puras sobre la vista y servicios de
## la cáscara (TableScreen). Los módulos se llaman entre sí a través de este
## objeto. Nadie guarda copias de `view`, `opts`, `selected`... entre llamadas:
## se reasignan en cada set_view (y `selected` en varios sitios).

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
## Datos de la jugada o elección en curso (antes `_flow`; `flow` es el módulo).
var flow_data: Dictionary = {}
var pflow: PlayFlow = null
var step: Step = Step.NONE
var shown_prompt_id: int = -1

## Módulos (Node hijos de la mesa). El orden es el de consulta de on_dialog_button.
var modules: Array[TableModule] = []
var sync: TableSync
var menu: TableMenu
var players: TablePlayers
var center: TableCenter
var hand: TableHand
var actions: TableActions
var flow: TableFlow
var mode_bar: TableModeBar
var dialogs: TableDialogs
var prompts: TablePrompts
var notices: TableNotices
var game_over: TableGameOver


# ---------------------------------------------------------------- servicios de la cáscara

func refresh() -> void:
	screen.refresh()


func emit_action(a: Dictionary) -> void:
	screen.emit_action(a)


func toast(text: String) -> void:
	screen.show_toast(text)


func zoom(card: Dictionary, def: Dictionary) -> void:
	screen.show_zoom(card, def)


## Capa modal: fondo oscuro + contenido centrado. No la añade a la mesa.
static func make_overlay(content: Control, width: float) -> Control:
	var ov: Control = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.z_index = 50
	ov.visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	content.custom_minimum_size = Vector2(width, 0)
	content.visible = true
	cc.add_child(content)
	return ov


# ---------------------------------------------------------------- estado de la jugada

func reset_flow() -> void:
	flow_data = {}
	pflow = null
	step = Step.NONE
	selected.clear()
	pay_table.clear()


## Pago elegido: cartas de la mano + comodines en mesa.
func payment() -> Array:
	var out: Array = []
	for x: int in selected:
		out.append(x)
	for x: int in pay_table:
		out.append(x)
	return out


func allowed() -> Array[String]:
	if pflow != null and FLOW_KINDS_PLAY.has(String(flow_data.get("kind", ""))):
		var out: Array[String] = pflow.target_choices()
		for t: String in pflow.targets:
			if not out.has(t):
				out.append(t)
		return out
	var res: Array[String] = []
	for a: Variant in flow_data.get("allowed", []) as Array:
		res.append(String(a))
	return res


func flow_targets() -> Array[String]:
	if pflow != null and FLOW_KINDS_PLAY.has(String(flow_data.get("kind", ""))):
		return pflow.targets.duplicate()
	var out: Array[String] = []
	for a: Variant in flow_data.get("targets", []) as Array:
		out.append(String(a))
	return out


# ---------------------------------------------------------------- consultas sobre la vista

func me() -> Dictionary:
	return Types.get_player(view, viewer_id)


static func name_of(v: Dictionary, pid: String) -> String:
	var p: Dictionary = Types.get_player(v, pid)
	return String(p.get("name", pid))


func names() -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in view.get("players", []) as Array:
		var pd: Dictionary = p
		out[String(pd["id"])] = String(pd["name"])
	return out


func turn_info() -> Dictionary:
	return view.get("turn", {}) as Dictionary


func is_my_turn() -> bool:
	return String(turn_info().get("current", "")) == viewer_id


func playing() -> bool:
	return String(view.get("status", "")) == Types.STATUS_PLAYING


func my_prompts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pr: Variant in view.get("pending", []) as Array:
		var prd: Dictionary = pr
		if String(prd.get("player", "")) == viewer_id:
			out.append(prd)
	return out


## ¿Puede hacer acciones de turno ahora (jugar, descartar, intercambiar...)?
func can_act() -> bool:
	return opts.in_turn()


func exchange_cost() -> int:
	if not can_act():
		return -1
	return Damage.exchange_cost(view, viewer_id, false)


func drink_text(p_me: Dictionary) -> String:
	var cfg: Dictionary = view.get("config", {}) as Dictionary
	var n: int = int(p_me.get("potions", 0))
	if bool(cfg.get("potion_limit_enabled", false)):
		return "Beber poción  (%d/%d)" % [n, int(cfg.get("potion_limit", 10))]
	return "Beber poción  (%d)" % n


## ¿La próxima poción del que mira lo eliminaría por Too Much Mana?
func drink_would_eliminate() -> bool:
	var cfg: Dictionary = view.get("config", {}) as Dictionary
	var p_me: Dictionary = me()
	if p_me.is_empty() or not bool(cfg.get("potion_limit_enabled", false)):
		return false
	return int(p_me.get("potions", 0)) >= int(cfg.get("potion_limit", 10))


func drink_label() -> String:
	return "Beber poción (¡eliminado!)" if drink_would_eliminate() else "Beber poción"


func find_in_hand(iid: int) -> Dictionary:
	for c: Variant in me().get("hand", []) as Array:
		if int((c as Dictionary)["iid"]) == iid:
			return c as Dictionary
	return {}


func find_curse_of_rules() -> Dictionary:
	for p: Variant in view.get("players", []) as Array:
		for c: Variant in (p as Dictionary).get("curses", []) as Array:
			if String((c as Dictionary).get("card_id", "")) == Types.CARD_CURSE_OF_RULES:
				return c as Dictionary
	return {}


func find_my_artifact(card_id: String) -> int:
	for a: Variant in me().get("artifacts", []) as Array:
		if String((a as Dictionary).get("card_id", "")) == card_id:
			return int((a as Dictionary)["iid"])
	return -1


## Carta en juego (mesa, evento, hechizo o respuesta en la ventana) por iid.
func card_in_play(iid: int) -> Dictionary:
	var re: Dictionary = view.get("reaction", {}) as Dictionary
	if not re.is_empty():
		var spells: Array = [re.get("spell", {})]
		spells.append_array(re.get("stack", []) as Array)
		for sp: Variant in spells:
			var c: Dictionary = (sp as Dictionary).get("card", {}) as Dictionary
			if int(c.get("iid", -1)) == iid:
				return c
	for p: Variant in view.get("players", []) as Array:
		for zone: String in ["artifacts", "curses"]:
			for c: Variant in (p as Dictionary).get(zone, []) as Array:
				if int((c as Dictionary).get("iid", -1)) == iid:
					return {"iid": iid, "card_id": String((c as Dictionary)["card_id"])}
	var ev: Dictionary = view.get("active_event", {}) as Dictionary
	if int(ev.get("iid", -1)) == iid:
		return {"iid": iid, "card_id": String(ev["card_id"])}
	return {"iid": iid, "card_id": ""}


static func source_name(pr: Dictionary) -> String:
	var src: String = String(pr.get("source", ""))
	if src == "":
		return ""
	return String(UiUtil.card_def(src).get("name", src))
