class_name ActionOptions
extends RefCounted
## Acciones legales de un jugador sobre una VISTA (Types.view_for o
## compose_view), indexadas para que la UI habilite solo lo legal.
##
## Usa Game.legal_actions(view, pid). Por el contrato A1 (CONTRATO-TIPOS.md)
## las acciones legales no leen información oculta, así que sobre la vista dan
## lo mismo que sobre el estado (Magic Hand sale de view.reveals[pid]).
## Funciona igual en local y en línea.

var view: Dictionary = {}
var pid: String = ""
var actions: Array = []


static func build(p_view: Dictionary, p_pid: String) -> ActionOptions:
	var o: ActionOptions = ActionOptions.new()
	o.view = p_view
	o.pid = p_pid
	if p_view.is_empty() or p_pid == "" or String(p_view.get("status", "")) != Types.STATUS_PLAYING:
		return o
	if Types.get_player(p_view, p_pid).is_empty():
		return o
	o.actions = Game.legal_actions(p_view, p_pid)
	return o


## Última mano revelada (kind "hand") de `of` para `viewer`.
static func revealed_hand(v: Dictionary, viewer: String, of: String) -> Array:
	return SupportEffects.revealed_hand(v, viewer, of)


func is_empty() -> bool:
	return actions.is_empty()


func of_type(t: String) -> Array:
	var out: Array = []
	for a: Variant in actions:
		if String((a as Dictionary)["type"]) == t:
			out.append(a)
	return out


func has_type(t: String) -> bool:
	for a: Variant in actions:
		if String((a as Dictionary)["type"]) == t:
			return true
	return false


## ¿Puede hacer acciones de turno (jugar, descartar, intercambiar, terminar)?
func in_turn() -> bool:
	return has_type(Types.ACTION_END_TURN)


func can_end_turn() -> bool:
	return in_turn()


## Descartar: cualquier subconjunto no vacío de la mano durante el turno.
func can_discard(cards: Array) -> bool:
	if not in_turn() or cards.is_empty():
		return false
	var hand_ids: Array = _hand_ids()
	for x: Variant in cards:
		if not hand_ids.has(int(x)):
			return false
	return true


func can_exchange(iid: int) -> bool:
	for a: Variant in of_type(Types.ACTION_EXCHANGE):
		if int((a as Dictionary)["card"]) == iid:
			return true
	return false


func can_drink() -> bool:
	return has_type(Types.ACTION_DRINK_POTION)


func can_pass_reaction() -> bool:
	return has_type(Types.ACTION_PASS_REACTION)


## Jugadas legales (PLAY_CARD) de la carta iid.
func plays_for(iid: int) -> Array:
	return _card_actions(Types.ACTION_PLAY_CARD, iid)


## Respuestas legales (REACT) con la carta iid.
func reacts_for(iid: int) -> Array:
	return _card_actions(Types.ACTION_REACT, iid)


func playable_iids() -> Array[int]:
	return _iids_of(Types.ACTION_PLAY_CARD)


func reactable_iids() -> Array[int]:
	return _iids_of(Types.ACTION_REACT)


## Acciones que responden al prompt pr_id (opcionalmente de un tipo).
func prompt_actions(pr_id: int, t: String = "") -> Array:
	var out: Array = []
	for a: Variant in actions:
		var ad: Dictionary = a
		if int(ad.get("prompt_id", -1)) != pr_id:
			continue
		if t != "" and String(ad["type"]) != t:
			continue
		out.append(ad)
	return out


## USE_ARTIFACT legales (sin prompt) del artefacto iid.
func artifact_uses(iid: int) -> Array:
	var out: Array = []
	for a: Variant in of_type(Types.ACTION_USE_ARTIFACT):
		var ad: Dictionary = a
		if int(ad["card"]) == iid and int(ad.get("prompt_id", -1)) < 0:
			out.append(ad)
	return out


## iids de artefactos propios con algún uso legal ahora.
func usable_artifacts() -> Array[int]:
	var out: Array[int] = []
	for a: Variant in of_type(Types.ACTION_USE_ARTIFACT):
		var ad: Dictionary = a
		if int(ad.get("prompt_id", -1)) < 0 and not out.has(int(ad["card"])):
			out.append(int(ad["card"]))
	return out


## ¿La acción `a` (tal cual) está entre las legales? Compara tipo y campos.
func contains(a: Dictionary) -> bool:
	for x: Variant in actions:
		if same_action(x as Dictionary, a):
			return true
	return false


## Igualdad de acciones; targets, payment y cards se comparan como conjuntos.
static func same_action(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k: Variant in a:
		if not b.has(k):
			return false
		if String(k) in ["targets", "payment", "cards"]:
			if not same_set(a[k] as Array, b[k] as Array):
				return false
		elif a[k] != b[k]:
			return false
	return true


static func same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x: Variant in a:
		if not b.has(x):
			return false
	return true


func _card_actions(t: String, iid: int) -> Array:
	var out: Array = []
	for a: Variant in actions:
		var ad: Dictionary = a
		if String(ad["type"]) == t and int(ad["card"]) == iid:
			out.append(ad)
	return out


func _iids_of(t: String) -> Array[int]:
	var out: Array[int] = []
	for a: Variant in of_type(t):
		var iid: int = int((a as Dictionary)["card"])
		if not out.has(iid):
			out.append(iid)
	return out


func _hand_ids() -> Array:
	var out: Array = []
	for c: Variant in Types.get_player(view, pid).get("hand", []) as Array:
		out.append(int((c as Dictionary)["iid"]))
	return out
