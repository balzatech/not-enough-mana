class_name Reactions
extends RefCounted
## Ventana de reacción y pila de respuestas (T6b).
##
## Flujo (lo llama Game, ver la cabecera de game.gd):
##  * open(state, spell, events): tras lanzar un hechizo (is_spell). Calcula el
##    orden de respuesta (primero el objetivo y luego los demás en sentido
##    horario, incluido el lanzador) y se queda solo con quienes PUEDEN
##    responder (tienen una defensiva, o una carta aceptada por el hook
##    HOOK_CAN_RESPOND, con objetivos válidos, pago en cartas posible y maná
##    suficiente contando las pociones que aún pueden beber sin pasarse de
##    Too Much Mana). Si nadie puede, no abre la ventana y resuelve el hechizo.
##  * handle(state, action, events): REACT / PASS_REACTION. Decide SIEMPRE
##    awaiting[0] (orden estricto); los demás reciben ERR_NOT_YOUR_DECISION.
##    - PASS_REACTION: sale de awaiting. Si awaiting queda vacío, se cierra.
##    - REACT: paga (maná + cartas, fuera de turno), apila la respuesta
##      (make_spell con is_response=true) y empieza una ronda nueva: vuelven a
##      decidir todos los que puedan, empezando por el objetivo.
##  * Al cerrar: la pila se resuelve en orden inverso (LIFO) y después el
##    hechizo con Game.resolve_spell (ya fuera de state.reaction). Una respuesta
##    o un hechizo con cancelled = true (Annihilation) va al descarte sin efecto.
##
## Temporizador: el motor no lee el reloj. La sesión fija deadline_ms (helper
## set_deadline) y, cuando is_expired(state, now_ms), envía timeout_actions():
## un PASS_REACTION por cada jugador de awaiting, en orden (mismo efecto que
## pasar todos). El motor pone deadline_ms = 0 al empezar cada ronda nueva
## (tras un REACT): 0 significa "la sesión debe fijar un plazo nuevo".
##
## Datos de cada respuesta apilada (spell.data):
##  payment:Array[int]   iids con los que pagó
##  spell_iid:int        iid del hechizo original (al que se ligan los modificadores)
##  responds_to:int      iid de la carta a la que responde (cima de la pila al jugarla)
##
## PUNTO DE EXTENSIÓN (Lightning encadenado, T6a):
##  Cartas no defensivas que pueden jugarse con REACT registran el hook
##      EffectRegistry.register_hook(Reactions.HOOK_CAN_RESPOND, card_id, fn)
##  fn(state, ctx) -> Dictionary NO debe mutar state. ctx = make_effect_ctx
##  (card, def, caster=quien responde, targets, extra) + target_card, payment,
##  action, reaction (state.reaction), responding_to (Reactions.top_spell) y
##  ok:bool=false. Pone ctx.ok = true si la carta puede responder ahora y/o
##  ctx.error = ERR_* si los objetivos no valen. Los objetivos se validan antes
##  según def.target (vivos; si def.is_spell, Force Field → ERR_TARGET_IMMUNE).
##  Al resolverse (LIFO) se llama al efecto normal de la carta con
##  ctx.is_response = true y ctx.spell = la respuesta; el efecto puede modificar
##  la carta a la que responde con Reactions.find_spell(state, responds_to)
##  (referencia viva: cambiar targets, data.damage_bonus…). Patrón Lightning:
##      var me: Dictionary = ctx["spell"]
##      var prev: Dictionary = Reactions.find_spell(state, int(me["data"]["responds_to"]))
##      prev["data"]["damage_bonus"] = bonus(prev) + 1 + bonus(me)
##      prev["targets"] = me["targets"].duplicate()
##  Como la pila es LIFO, cada eslabón actualiza al anterior y el último en
##  resolverse (el primer encadenado) deja al hechizo original con el objetivo
##  final y el bono acumulado.
##
## Ventana "huérfana": si todos los de awaiting quedan eliminados (Too Much
## Mana, rendirse…) cualquier jugador vivo puede enviar PASS_REACTION para
## cerrarla; sync(state, events) hace la misma limpieza sin acción.

const HOOK_CAN_RESPOND: String = Types.HOOK_CAN_RESPOND

## Pociones "ilimitadas" al calcular si alguien puede pagar (sin Too Much Mana).
const UNLIMITED_POTIONS: int = 99


# =============================================================================
# API que usa Game
# =============================================================================

## Abre la ventana para `spell` (ya fuera de la mano y pagado). Si nadie puede
## responder, lo resuelve directamente. Devuelve {state, error}.
static func open(state: Dictionary, spell: Dictionary, events: Array) -> Dictionary:
	state["reaction"] = Types.make_reaction(spell)
	var awaiting: Array = eligible_order(state)
	if awaiting.is_empty():
		state["reaction"] = {}
		return Game.resolve_spell(state, spell, events)
	var re: Dictionary = state["reaction"]
	re["awaiting"] = awaiting
	var card: Dictionary = spell["card"]
	events.append(Types.make_log_entry(Types.LOG_REACTION_OPENED, Damage.turn_no(state), String(spell["caster"]), {
		"iid": int(card["iid"]), "card_id": String(card["card_id"]),
		"targets": (spell["targets"] as Array).duplicate(), "awaiting": awaiting.duplicate(),
	}))
	return {"state": state, "error": Types.ERR_NONE}


## REACT / PASS_REACTION con la ventana abierta. Devuelve {state, error}.
static func handle(state: Dictionary, action: Dictionary, events: Array) -> Dictionary:
	var re: Dictionary = state["reaction"]
	if re.is_empty():
		return {"state": state, "error": Types.ERR_NO_REACTION}
	var pid: String = action["player"]
	_prune(state)
	var awaiting: Array = re["awaiting"]
	var t: String = action["type"]
	if awaiting.is_empty():
		if t == Types.ACTION_PASS_REACTION:
			return close(state, events)
		return {"state": state, "error": Types.ERR_NOT_YOUR_DECISION}
	if String(awaiting[0]) != pid:
		return {"state": state, "error": Types.ERR_NOT_YOUR_DECISION}
	if t == Types.ACTION_PASS_REACTION:
		awaiting.remove_at(0)
		(re["passed"] as Array).append(pid)
		events.append(Types.make_log_entry(Types.LOG_REACTION_PASSED, Damage.turn_no(state), pid))
		_prune(state)
		if (re["awaiting"] as Array).is_empty():
			return close(state, events)
		return {"state": state, "error": Types.ERR_NONE}
	if t != Types.ACTION_REACT:
		return {"state": state, "error": Types.ERR_INVALID_ACTION}
	var p: Dictionary = Types.get_player(state, pid)
	var chk: Dictionary = check_react(state, pid, action, int(p["mana"]))
	if String(chk["error"]) != Types.ERR_NONE:
		return {"state": state, "error": String(chk["error"])}
	_apply_react(state, pid, action, chk, events)
	re["passed"] = []
	re["deadline_ms"] = 0
	re["awaiting"] = eligible_order(state)
	if (re["awaiting"] as Array).is_empty():
		return close(state, events)
	return {"state": state, "error": Types.ERR_NONE}


## Acciones de ventana para pid: si le toca decidir, PASS_REACTION y todos los
## REACT que puede pagar ahora (sin beber). Si la ventana está huérfana, PASS.
static func legal_actions(state: Dictionary, pid: String) -> Array:
	var out: Array = []
	var re: Dictionary = state["reaction"]
	if re.is_empty():
		return out
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]):
		return out
	var cur: String = current_responder(state)
	if cur == "":
		out.append(Types.make_action_pass_reaction(pid))
		return out
	if cur != pid:
		return out
	out.append(Types.make_action_pass_reaction(pid))
	for c: Variant in p["hand"]:
		out.append_array(_card_reacts(state, pid, c as Dictionary, int(p["mana"]), false))
	return out


## Quita de awaiting a los eliminados y, si queda vacío, cierra la ventana.
## Pensado para llamarse tras acciones que pueden eliminar a alguien durante
## la ventana (pociones, rendirse). Devuelve {state, error}.
static func sync(state: Dictionary, events: Array) -> Dictionary:
	if (state["reaction"] as Dictionary).is_empty():
		return {"state": state, "error": Types.ERR_NONE}
	_prune(state)
	if ((state["reaction"] as Dictionary)["awaiting"] as Array).is_empty():
		return close(state, events)
	return {"state": state, "error": Types.ERR_NONE}


# =============================================================================
# Temporizador (helpers para la capa de sesión; el motor no lee el reloj)
# =============================================================================

## Copia del estado con reaction.deadline_ms = now_ms + timeout_ms. Si no hay
## ventana o timeout_ms <= 0, devuelve el estado sin cambios.
static func set_deadline(state: Dictionary, now_ms: int, timeout_ms: int) -> Dictionary:
	if (state["reaction"] as Dictionary).is_empty() or timeout_ms <= 0:
		return state
	var s: Dictionary = state.duplicate(true)
	(s["reaction"] as Dictionary)["deadline_ms"] = now_ms + timeout_ms
	return s


## ¿Hay ventana abierta sin plazo (la sesión debe fijar uno si usa temporizador)?
static func needs_deadline(state: Dictionary) -> bool:
	var re: Dictionary = state["reaction"]
	return not re.is_empty() and int(re["deadline_ms"]) == 0


static func is_expired(state: Dictionary, now_ms: int) -> bool:
	var re: Dictionary = state["reaction"]
	return not re.is_empty() and int(re["deadline_ms"]) > 0 and now_ms >= int(re["deadline_ms"])


## Acciones que la sesión envía, en orden, al vencer el plazo: un PASS_REACTION
## por cada jugador pendiente (o uno de cualquier vivo si la ventana está huérfana).
static func timeout_actions(state: Dictionary) -> Array:
	var out: Array = []
	var re: Dictionary = state["reaction"]
	if re.is_empty():
		return out
	for x: Variant in re["awaiting"]:
		var pd: Dictionary = Types.get_player(state, String(x))
		if not pd.is_empty() and not bool(pd["eliminated"]):
			out.append(Types.make_action_pass_reaction(String(x)))
	if out.is_empty():
		var alive: Array[String] = Types.alive_ids(state)
		if not alive.is_empty():
			out.append(Types.make_action_pass_reaction(alive[0]))
	return out


# =============================================================================
# Consultas
# =============================================================================

## Quién debe decidir ahora ("" si no hay ventana o nadie vivo pendiente).
static func current_responder(state: Dictionary) -> String:
	var re: Dictionary = state["reaction"]
	if re.is_empty():
		return ""
	for x: Variant in re["awaiting"]:
		var pd: Dictionary = Types.get_player(state, String(x))
		if not pd.is_empty() and not bool(pd["eliminated"]):
			return String(x)
	return ""


## Referencia viva al hechizo (o respuesta apilada) con ese iid; {} si no está.
static func find_spell(state: Dictionary, iid: int) -> Dictionary:
	var re: Dictionary = state.get("reaction", {})
	if re.is_empty():
		return {}
	var main: Dictionary = re["spell"]
	if not main.is_empty() and int((main["card"] as Dictionary)["iid"]) == iid:
		return main
	for x: Variant in re["stack"]:
		var sd: Dictionary = x
		if int((sd["card"] as Dictionary)["iid"]) == iid:
			return sd
	return {}


## Cima de la pila o, si está vacía, el hechizo original ({} sin ventana).
static func top_spell(state: Dictionary) -> Dictionary:
	var re: Dictionary = state.get("reaction", {})
	if re.is_empty():
		return {}
	var stack: Array = re["stack"]
	if not stack.is_empty():
		return stack[stack.size() - 1]
	return re["spell"]


## iids de cartas que se pueden "anular" en la ventana: hechizo y respuestas
## apiladas no canceladas.
static func reaction_iids(state: Dictionary) -> Array:
	var out: Array = []
	var re: Dictionary = state.get("reaction", {})
	if re.is_empty():
		return out
	var all: Array = [re["spell"]]
	all.append_array(re["stack"] as Array)
	for x: Variant in all:
		var sd: Dictionary = x
		if not sd.is_empty() and not bool(sd["cancelled"]):
			out.append(int((sd["card"] as Dictionary)["iid"]))
	return out


## Orden de respuesta: primero el objetivo del hechizo "en foco" (la respuesta
## apilada más alta que sea un hechizo, p. ej. un Lightning encadenado; si no,
## el hechizo original) y luego el resto de vivos en sentido horario.
static func response_order(state: Dictionary) -> Array:
	var re: Dictionary = state["reaction"]
	var focus: Dictionary = re["spell"]
	var stack: Array = re["stack"]
	for i: int in range(stack.size() - 1, -1, -1):
		var sd: Dictionary = stack[i]
		var d: Dictionary = CardCatalog.get_def(String((sd["card"] as Dictionary)["card_id"]))
		if bool(d.get("is_spell", false)) and not bool(sd["cancelled"]):
			focus = sd
			break
	var ps: Array = state["players"]
	var n: int = ps.size()
	var out: Array = []
	if n == 0:
		return out
	var caster: String = focus["caster"]
	var targets: Array = focus["targets"]
	var ci: int = maxi(0, Types.player_index(state, caster))
	var start: int = -1
	for k: int in range(1, n + 1):
		var pd: Dictionary = ps[posmod(ci + k, n)]
		if not bool(pd["eliminated"]) and targets.has(String(pd["id"])):
			start = posmod(ci + k, n)
			break
	if start < 0:
		start = posmod(ci + 1, n)
	for k: int in n:
		var pd: Dictionary = ps[posmod(start + k, n)]
		if not bool(pd["eliminated"]):
			out.append(String(pd["id"]))
	return out


## response_order filtrado a quienes pueden responder.
static func eligible_order(state: Dictionary) -> Array:
	var out: Array = []
	for x: Variant in response_order(state):
		if can_respond(state, String(x)):
			out.append(x)
	return out


## ¿pid tiene alguna respuesta legal pagable (contando pociones que puede beber)?
static func can_respond(state: Dictionary, pid: String) -> bool:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]):
		return false
	var budget: int = int(p["mana"]) + potion_capacity(state, pid)
	for c: Variant in p["hand"]:
		if not _card_reacts(state, pid, c as Dictionary, budget, true).is_empty():
			return true
	return false


## Maná que pid aún puede conseguir bebiendo sin quedar eliminado por Too Much
## Mana (limitado por el pool común si está activo).
static func potion_capacity(state: Dictionary, pid: String) -> int:
	var p: Dictionary = Types.get_player(state, pid)
	var cfg: Dictionary = state["config"]
	var left: int = UNLIMITED_POTIONS
	if bool(cfg["potion_limit_enabled"]):
		left = maxi(0, int(cfg["potion_limit"]) - int(p["potions"]))
	var cap: int = Damage.potion_amount(state, pid, false) * left
	if bool(cfg["pool_enabled"]):
		cap = mini(cap, int((state["pool"] as Dictionary)["mana"]))
	return maxi(0, cap)


## Valida un REACT de pid sin aplicar nada. budget = maná disponible.
## Devuelve {error, targets, pay_hand, pay_table, cost}.
static func check_react(state: Dictionary, pid: String, a: Dictionary, budget: int) -> Dictionary:
	var out: Dictionary = {"error": Types.ERR_NONE, "targets": [], "pay_hand": [], "pay_table": [], "cost": 0}
	var p: Dictionary = Types.get_player(state, pid)
	var iid: int = a["card"]
	var hi: int = Deck.hand_index(p, iid)
	if hi < 0:
		out["error"] = Types.ERR_CARD_NOT_IN_HAND
		return out
	var card: Dictionary = (p["hand"] as Array)[hi]
	var card_id: String = card["card_id"]
	var def: Dictionary = CardCatalog.get_def(card_id)
	if def.is_empty():
		out["error"] = Types.ERR_UNKNOWN_CARD
		return out
	if not bool(def.get("playable", false)):
		out["error"] = Types.ERR_CARD_NOT_PLAYABLE
		return out
	var is_def: bool = String(def.get("type", "")) == Types.CARD_TYPE_DEFENSIVE
	var hook: Callable = EffectRegistry.get_hook(HOOK_CAN_RESPOND, card_id)
	if not is_def and not hook.is_valid():
		out["error"] = Types.ERR_CARD_NOT_PLAYABLE
		return out
	if not EffectRegistry.has_effect(card_id):
		out["error"] = Types.ERR_NO_EFFECT
		return out
	var tres: Dictionary = _resolve_targets(state, pid, def, a["targets"] as Array, int(a["target_card"]), iid)
	if String(tres["error"]) != Types.ERR_NONE:
		out["error"] = tres["error"]
		return out
	out["targets"] = tres["targets"]
	var ctx: Dictionary = Types.make_effect_ctx(card, def, pid, tres["targets"] as Array, a["extra"] as Dictionary)
	ctx["target_card"] = int(a["target_card"])
	ctx["payment"] = (a["payment"] as Array).duplicate()
	ctx["action"] = a
	ctx["reaction"] = state["reaction"]
	ctx["responding_to"] = top_spell(state)
	ctx["ok"] = is_def
	if is_def:
		DefensiveEffects.check_response(state, ctx)
	if hook.is_valid():
		hook.call(state, ctx)
	if String(ctx["error"]) != Types.ERR_NONE:
		out["error"] = ctx["error"]
		return out
	if not bool(ctx["ok"]):
		out["error"] = Types.ERR_CARD_NOT_PLAYABLE
		return out
	var pay: Dictionary = Game.check_payment(state, pid, def, iid, a["payment"] as Array)
	if String(pay["error"]) != Types.ERR_NONE:
		out["error"] = pay["error"]
		return out
	out["pay_hand"] = pay["hand"]
	out["pay_table"] = pay["table"]
	var cost: int = Damage.card_cost(state, pid, def, iid, false)
	out["cost"] = cost
	if cost > budget:
		out["error"] = Types.ERR_INSUFFICIENT_MANA
	return out


# =============================================================================
# Cierre y resolución
# =============================================================================

## Resuelve la pila (LIFO) y luego el hechizo original. Los errores de efectos
## al cerrar no bloquean la partida: la carta "falla" (fizzle) y se registra.
static func close(state: Dictionary, events: Array) -> Dictionary:
	DefensiveEffects.drain_side_events()
	var guard: int = 0
	while guard < Game.MAX_LOOP:
		guard += 1
		var re: Dictionary = state["reaction"]
		var stack: Array = re["stack"]
		if stack.is_empty():
			break
		var resp: Dictionary = stack.pop_back()
		_resolve_response(state, resp, events)
		events.append_array(DefensiveEffects.drain_side_events())
	var spell: Dictionary = (state["reaction"] as Dictionary)["spell"]
	state["reaction"] = {}
	var r: Dictionary = Game.resolve_spell(state, spell, events)
	_adopt(state, r.get("state", state))
	events.append_array(DefensiveEffects.drain_side_events())
	var err: String = String(r.get("error", Types.ERR_NONE))
	if err != Types.ERR_NONE:
		_fizzle(state, spell, err, events)
	return {"state": state, "error": Types.ERR_NONE}


static func _resolve_response(state: Dictionary, resp: Dictionary, events: Array) -> void:
	var card: Dictionary = resp["card"]
	var iid: int = card["iid"]
	var card_id: String = card["card_id"]
	var caster: String = resp["caster"]
	if bool(resp["cancelled"]):
		Modifiers.expire(state, Types.EXPIRES_SPELL, "", iid)
		if not Types.all_card_iids(state).has(iid):
			Deck.to_discard(state, card)
		events.append(Types.make_log_entry(Types.LOG_SPELL_CANCELLED, Damage.turn_no(state), caster,
			{"iid": iid, "card_id": card_id, "response": true}))
		return
	var def: Dictionary = CardCatalog.get_def(card_id)
	var ctx: Dictionary = Types.make_effect_ctx(card, def, caster, resp["targets"] as Array, resp["extra"] as Dictionary)
	ctx["target_card"] = int(resp["target_card"])
	ctx["payment"] = ((resp["data"] as Dictionary).get("payment", []) as Array).duplicate()
	ctx["spell"] = resp
	ctx["is_response"] = true
	ctx["events"] = events
	var fn: Callable = EffectRegistry.get_effect(card_id)
	if fn.is_valid():
		_adopt(state, fn.call(state, ctx))
	if String(ctx["error"]) != Types.ERR_NONE:
		_fizzle(state, resp, String(ctx["error"]), events)
		return
	Modifiers.expire(state, Types.EXPIRES_SPELL, "", iid)
	if not Types.all_card_iids(state).has(iid):
		Deck.to_discard(state, card)
	events.append(Types.make_log_entry(Types.LOG_SPELL_RESOLVED, Damage.turn_no(state), caster, {
		"iid": iid, "card_id": card_id, "targets": (resp["targets"] as Array).duplicate(),
		"target_card": int(resp["target_card"]), "response": true,
	}))


static func _fizzle(state: Dictionary, spell: Dictionary, err: String, events: Array) -> void:
	var card: Dictionary = spell["card"]
	var iid: int = card["iid"]
	Modifiers.expire(state, Types.EXPIRES_SPELL, "", iid)
	if not Types.all_card_iids(state).has(iid):
		Deck.to_discard(state, card)
	events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), String(spell["caster"]),
		{"card_id": String(card["card_id"]), "iid": iid, "what": "fizzled", "error": err}))


# =============================================================================
# Internos
# =============================================================================

static func _apply_react(state: Dictionary, pid: String, a: Dictionary, chk: Dictionary, events: Array) -> void:
	var p: Dictionary = Types.get_player(state, pid)
	var iid: int = a["card"]
	var card: Dictionary = Deck.take_from_hand(p, iid)
	var def: Dictionary = CardCatalog.get_def(String(card["card_id"]))
	var cost: int = Damage.card_cost(state, pid, def, iid, true)
	Damage.pay_mana(state, pid, cost)
	var paid_ids: Array = []
	var paid_cards: Array = []
	for x: Variant in chk["pay_hand"]:
		var pc: Dictionary = Deck.take_from_hand(p, int(x))
		Deck.to_discard(state, pc)
		paid_ids.append(int(x))
		paid_cards.append(String(pc["card_id"]))
	for x: Variant in chk["pay_table"]:
		var found: Dictionary = Deck.find_in_play(state, int(x))
		var tc: Dictionary = found["card"]
		var fn: Callable = EffectRegistry.get_hook(Types.HOOK_PAY_WILDCARD, String(tc["card_id"]))
		var ctx: Dictionary = Types.make_effect_ctx(tc, CardCatalog.get_def(String(tc["card_id"])), pid)
		ctx["events"] = events
		ctx["mode"] = "consume"
		ctx["def"] = def
		if fn.is_valid():
			_adopt(state, fn.call(state, ctx))
		paid_ids.append(int(x))
		paid_cards.append(String(tc["card_id"]))
	var re: Dictionary = state["reaction"]
	var main: Dictionary = re["spell"]
	var responds_to: int = int((top_spell(state)["card"] as Dictionary)["iid"])
	var resp: Dictionary = Types.make_spell(card, pid, chk["targets"] as Array, a["extra"] as Dictionary,
		true, int(a["target_card"]))
	var data: Dictionary = resp["data"]
	data["payment"] = paid_ids
	data["spell_iid"] = int((main["card"] as Dictionary)["iid"])
	data["responds_to"] = responds_to
	(re["stack"] as Array).append(resp)
	events.append(Types.make_log_entry(Types.LOG_REACTED, Damage.turn_no(state), pid, {
		"iid": iid, "card_id": String(card["card_id"]), "targets": (chk["targets"] as Array).duplicate(),
		"target_card": int(a["target_card"]), "payment": paid_ids, "payment_cards": paid_cards,
		"cost": cost, "responds_to": responds_to,
	}))


## Quita de awaiting a los eliminados.
static func _prune(state: Dictionary) -> void:
	var re: Dictionary = state["reaction"]
	var kept: Array = []
	for x: Variant in re["awaiting"]:
		var pd: Dictionary = Types.get_player(state, String(x))
		if not pd.is_empty() and not bool(pd["eliminated"]):
			kept.append(x)
	re["awaiting"] = kept


## Objetivos de una respuesta según def.target. No usa Game._resolve_targets
## porque aquí Force Field solo afecta si la carta es un hechizo y porque
## Annihilation puede apuntar al hechizo en curso o a una respuesta apilada.
static func _resolve_targets(state: Dictionary, pid: String, def: Dictionary, raw: Array,
		target_card: int, own_iid: int) -> Dictionary:
	var alive: Array[String] = Types.alive_ids(state)
	var out: Dictionary = {"error": Types.ERR_NONE, "targets": []}
	var ids: Array = []
	for t: Variant in raw:
		if not (t is String) or ids.has(t):
			out["error"] = Types.ERR_INVALID_TARGET
			return out
		ids.append(t)
	var need: int = 0
	match String(def.get("target", Types.TARGET_NONE)):
		Types.TARGET_SINGLE, Types.TARGET_OTHER:
			need = 1
		Types.TARGET_TWO:
			need = 2
		Types.TARGET_ALL:
			out["targets"] = alive.duplicate()
			return out
		Types.TARGET_ALL_OTHERS:
			var others: Array = alive.duplicate()
			others.erase(pid)
			out["targets"] = others
			return out
		Types.TARGET_CARD_IN_PLAY:
			if target_card == own_iid or not ids.is_empty() \
					or (Deck.find_in_play(state, target_card).is_empty() and not reaction_iids(state).has(target_card)):
				out["error"] = Types.ERR_CARD_NOT_IN_PLAY
			return out
	if ids.size() != need:
		out["error"] = Types.ERR_INVALID_TARGET
		return out
	var mode: String = def.get("target", Types.TARGET_NONE)
	for t: Variant in ids:
		var tid: String = t
		if not alive.has(tid) or (mode == Types.TARGET_OTHER and tid == pid):
			out["error"] = Types.ERR_INVALID_TARGET
			return out
		var tp: Dictionary = Types.get_player(state, tid)
		if bool(def.get("is_spell", false)) and String((tp["flags"] as Dictionary)["force_field"]) != "":
			out["error"] = Types.ERR_TARGET_IMMUNE
			return out
	out["targets"] = ids
	return out


## REACT válidos de pid con `card` dentro de `budget` de maná. first_only:
## para en el primero (comprobar si puede responder).
static func _card_reacts(state: Dictionary, pid: String, card: Dictionary, budget: int, first_only: bool) -> Array:
	var out: Array = []
	var card_id: String = card["card_id"]
	var def: Dictionary = CardCatalog.get_def(card_id)
	if def.is_empty():
		return out
	if String(def.get("type", "")) != Types.CARD_TYPE_DEFENSIVE \
			and not EffectRegistry.get_hook(HOOK_CAN_RESPOND, card_id).is_valid():
		return out
	if not EffectRegistry.has_effect(card_id):
		return out
	var p: Dictionary = Types.get_player(state, pid)
	var alive: Array[String] = Types.alive_ids(state)
	var target_sets: Array = []
	var target_cards: Array = [-1]
	match String(def.get("target", Types.TARGET_NONE)):
		Types.TARGET_SINGLE:
			for t: String in alive:
				target_sets.append([t])
		Types.TARGET_OTHER:
			for t: String in alive:
				if t != pid:
					target_sets.append([t])
		Types.TARGET_TWO:
			target_sets = Game.combinations(Array(alive), 2)
		Types.TARGET_CARD_IN_PLAY:
			target_sets.append([])
			target_cards = reaction_iids(state)
			for x: Variant in in_play_iids(state):
				if not target_cards.has(x):
					target_cards.append(x)
		_:
			target_sets.append([])
	var extras: Array = DefensiveEffects.extra_options(state, pid, card_id)
	var n_req: int = 0
	for r: Variant in (def.get("cost", {}) as Dictionary).get("cards", []):
		n_req += int((r as Dictionary).get("count", 1))
	var pay_sets: Array = [[]]
	if n_req > 0:
		var pool_ids: Array = []
		for c: Variant in p["hand"]:
			var ci: int = (c as Dictionary)["iid"]
			if ci != int(card["iid"]):
				pool_ids.append(ci)
		for c: Variant in p["artifacts"]:
			var tc: Dictionary = c
			if EffectRegistry.get_hook(Types.HOOK_PAY_WILDCARD, String(tc["card_id"])).is_valid():
				pool_ids.append(int(tc["iid"]))
		pay_sets = Game.combinations(pool_ids, n_req)
	for tcard: Variant in target_cards:
		for ts: Variant in target_sets:
			for ex: Variant in extras:
				for ps: Variant in pay_sets:
					var a: Dictionary = Types.make_action_react(pid, int(card["iid"]), ts as Array, ps as Array,
						ex as Dictionary, int(tcard))
					if String(check_react(state, pid, a, budget)["error"]) == Types.ERR_NONE:
						out.append(a)
						if first_only:
							return out
	return out


## iids de cartas en mesa (artefactos, maldiciones y evento activo).
static func in_play_iids(state: Dictionary) -> Array:
	var out: Array = []
	for p: Variant in state["players"]:
		var pd: Dictionary = p
		for zone: String in ["artifacts", "curses"]:
			for c: Variant in pd[zone]:
				out.append(int((c as Dictionary)["iid"]))
	var ev: Dictionary = state["active_event"]
	if not ev.is_empty():
		out.append(int(ev["iid"]))
	return out


static func _adopt(s: Dictionary, ret: Variant) -> void:
	if ret is Dictionary and not is_same(ret, s):
		var d: Dictionary = ret
		if d.is_empty():
			return
		var copy: Dictionary = d.duplicate()
		s.clear()
		s.merge(copy)
