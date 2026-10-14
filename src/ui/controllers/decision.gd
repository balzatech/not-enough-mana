class_name Decision
extends RefCounted
## Quién debe decidir ahora, a partir de un estado o de una vista (la parte
## pública basta). Lo usan LocalSession (bots), la mesa (hot-seat y textos de
## espera) y, si quiere, OnlineSession.
##
## Prioridad: 1) dueño del primer prompt pendiente; 2) quien responde en la
## ventana de reacción (awaiting[0] vivo); 3) jugador en turno (fase principal).


## Decisor global ("" si nadie: partida terminada, fase de robo...).
static func decider(v: Dictionary) -> String:
	if String(v.get("status", "")) != Types.STATUS_PLAYING:
		return ""
	for pr: Variant in v.get("pending", []) as Array:
		var prd: Dictionary = pr
		if _alive(v, String(prd.get("player", ""))):
			return String(prd["player"])
	var resp: String = responder(v)
	if resp != "":
		return resp
	var turn: Dictionary = v.get("turn", {}) as Dictionary
	var cur: String = String(turn.get("current", ""))
	if String(turn.get("phase", "")) == Types.PHASE_MAIN and _alive(v, cur):
		return cur
	return ""


## Primer jugador de `ids` (p. ej. los humanos de este dispositivo) que tiene
## algo que decidir, con la misma prioridad. "" si ninguno.
static func local_decider(v: Dictionary, ids: Array[String]) -> String:
	if String(v.get("status", "")) != Types.STATUS_PLAYING:
		return ""
	for pr: Variant in v.get("pending", []) as Array:
		var prd: Dictionary = pr
		var owner: String = String(prd.get("player", ""))
		if ids.has(owner) and _alive(v, owner):
			return owner
	var resp: String = responder(v)
	if resp != "" and ids.has(resp):
		return resp
	if not (v.get("reaction", {}) as Dictionary).is_empty():
		return ""
	if not (v.get("pending", []) as Array).is_empty():
		return ""
	var turn: Dictionary = v.get("turn", {}) as Dictionary
	var cur: String = String(turn.get("current", ""))
	if ids.has(cur) and String(turn.get("phase", "")) == Types.PHASE_MAIN and _alive(v, cur):
		return cur
	return ""


## Quien decide en la ventana de reacción ("" si no hay ventana).
static func responder(v: Dictionary) -> String:
	var re: Dictionary = v.get("reaction", {}) as Dictionary
	if re.is_empty():
		return ""
	for x: Variant in re.get("awaiting", []) as Array:
		if _alive(v, String(x)):
			return String(x)
	return ""


static func _alive(v: Dictionary, pid: String) -> bool:
	if pid == "":
		return false
	var p: Dictionary = Types.get_player(v, pid)
	return not p.is_empty() and not bool(p.get("eliminated", false))
