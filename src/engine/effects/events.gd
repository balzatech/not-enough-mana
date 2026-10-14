class_name EventEffects
extends RefCounted
## Eventos (T6c). Firma: static func id(state: Dictionary, ctx: Dictionary) -> Dictionary
## Los llama Game.activate_event al robarse (ctx.caster = quien lo robó). Game
## ya ha retirado el evento anterior (HOOK_EVENT_END + Modifiers.expire
## next_event), así que los de duración "hasta el próximo evento" solo registran
## modificadores con EXPIRES_NEXT_EVENT y se revierten solos.
##
##  * Visit of the Archmage: PROMPT_DRINK_OR_SUFFER {hp:2} opcional a cada mago
##    vivo (en orden de turno desde quien lo robó). DRINK_POTION lo evita; DECLINE
##    (o el temporizador en línea) aplica 2 de daño sin elemento (lo gestiona T4).
##  * Not Enough Mana: after_damage custom "not_enough_mana": la víctima pierde
##    tanto 💧 como daño final recibido.
##  * Shot Glass: potion −1. Storms: outgoing +1 y cost +1 de su elemento (solo
##    hechizos). Disrupted Gravity: hand_limit +1 para todos.
##  * Mana Focus: custom "mana_focus" al final de redirect (y de prevent para el
##    daño redirigido): aplaza el daño y abre PROMPT_MANA_FOCUS {damage}; con
##    USE_EVENT {mana:k} el mago paga k💧 y recibe damage−k de daño; DECLINE =
##    recibe todo el daño. Solo si tiene maná.
##  * Blessing: +2💖 a todos. Warp Discharge: los empatados en el mínimo de 💧
##    reciben 1 de daño sin elemento; el resto +1💖.
##  * Elixir Transmutation: oportunidad única al revelarse: prompt
##    PROMPT_ELIXIR_TRANSMUTATION a cada mago vivo con vida < máximo; responde
##    USE_EVENT {amount:n} (n💖 a 2💧 cada uno) o DECLINE.

const VISIT_HP: int = 2
const BLESSING_HP: int = 2
const WARP_HP: int = 1
const ELIXIR_PRICE: int = 2

const HANDLER_NOT_ENOUGH_MANA: String = "not_enough_mana"
const HANDLER_MANA_FOCUS: String = "mana_focus"
const PRIORITY_MANA_FOCUS: int = 1000

## Workaround local: pedido como Types.PROMPT_ELIXIR_TRANSMUTATION en
## docs/CAMBIOS-TIPOS.md. data: {price:int, max:int}. USE_EVENT {amount} o DECLINE.
const PROMPT_ELIXIR_TRANSMUTATION: String = Types.PROMPT_ELIXIR_TRANSMUTATION


# =============================================================================
# Visit of the Archmage
# =============================================================================

static func visit_of_the_archmage(state: Dictionary, ctx: Dictionary) -> Dictionary:
	for pid: String in turn_order_from(state, String(ctx["caster"])):
		(state["pending"] as Array).append(Types.make_prompt(Types.next_seq(state), pid,
			Types.PROMPT_DRINK_OR_SUFFER, {"hp": VISIT_HP}, Types.CARD_VISIT_OF_THE_ARCHMAGE, true))
	return state


# =============================================================================
# Not Enough Mana
# =============================================================================

static func not_enough_mana(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var m: Dictionary = _mod(ctx, "", Types.STAGE_AFTER_DAMAGE, Types.OP_CUSTOM, 0, "")
	m["handler"] = HANDLER_NOT_ENOUGH_MANA
	Modifiers.add(state, m)
	return state


## Handler OP_CUSTOM (after_damage): la víctima pierde tanto maná como daño final.
## Los handlers no reciben `events`: el log va directo a state.log.
static func mod_not_enough_mana(state: Dictionary, _mod_d: Dictionary, ev: Dictionary) -> Dictionary:
	var amount: int = ev["amount"]
	if amount <= 0 or String(ev["kind"]) != Damage.KIND_DAMAGE:
		return ev
	var log_events: Array = []
	Damage.lose_mana(state, String(ev["target"]), amount, log_events, String(ev["source"]), Types.CARD_NOT_ENOUGH_MANA)
	(state["log"] as Array).append_array(log_events)
	return ev


# =============================================================================
# Shot Glass, Storms, Disrupted Gravity
# =============================================================================

static func shot_glass(state: Dictionary, ctx: Dictionary) -> Dictionary:
	Modifiers.add(state, _mod(ctx, "", Types.STAGE_POTION, Types.OP_SUB, 1, ""))
	return state


static func fire_storm(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _storm(state, ctx, Types.ELEMENT_FIRE)


static func ice_storm(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _storm(state, ctx, Types.ELEMENT_ICE)


static func lightning_storm(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _storm(state, ctx, Types.ELEMENT_ELECTRIC)


static func _storm(state: Dictionary, ctx: Dictionary, element: String) -> Dictionary:
	var dmg: Dictionary = _mod(ctx, "/dmg", Types.STAGE_OUTGOING, Types.OP_ADD, 1, element)
	dmg["spell_only"] = true
	Modifiers.add(state, dmg)
	var cost: Dictionary = _mod(ctx, "/cost", Types.STAGE_COST, Types.OP_ADD, 1, element)
	cost["spell_only"] = true
	Modifiers.add(state, cost)
	return state


static func disrupted_gravity(state: Dictionary, ctx: Dictionary) -> Dictionary:
	Modifiers.add(state, _mod(ctx, "", Types.STAGE_HAND_LIMIT, Types.OP_ADD, 1, ""))
	return state


# =============================================================================
# Mana Focus
# =============================================================================

static func mana_focus(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var a: Dictionary = _mod(ctx, "", Types.STAGE_REDIRECT, Types.OP_CUSTOM, 0, "")
	a["handler"] = HANDLER_MANA_FOCUS
	a["priority"] = PRIORITY_MANA_FOCUS
	Modifiers.add(state, a)
	var b: Dictionary = _mod(ctx, "/p", Types.STAGE_PREVENT, Types.OP_CUSTOM, 0, "")
	b["handler"] = HANDLER_MANA_FOCUS
	b["priority"] = PRIORITY_MANA_FOCUS
	Modifiers.add(state, b)
	return state


## Handler OP_CUSTOM: si la víctima tiene maná, aplaza el daño y le pregunta.
static func mod_mana_focus(state: Dictionary, mod_d: Dictionary, ev: Dictionary) -> Dictionary:
	if String(ev["kind"]) != Damage.KIND_DAMAGE or not ArtifactEffects.is_deferrable(ev, String(mod_d["stage"])):
		return ev
	var pid: String = ev["target"]
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]) or int(p["mana"]) <= 0:
		return ev
	(state["pending"] as Array).append(Types.make_prompt(Types.next_seq(state), pid, Types.PROMPT_MANA_FOCUS,
		{"damage": int(ev["amount"]), "loss": ArtifactEffects.loss_snapshot(ev)}, Types.CARD_MANA_FOCUS, true))
	return ArtifactEffects.defer(ev, Types.CARD_MANA_FOCUS)


## HOOK_USE_EVENT de TODOS los eventos: Game enruta USE_EVENT por el evento
## activo, pero un prompt de Mana Focus o Elixir Transmutation puede seguir
## pendiente cuando ya ha salido otro evento. Se despacha por el kind del prompt.
static func use_event_prompt(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var pr: Dictionary = (ctx["extra"] as Dictionary).get("prompt", {})
	if pr.is_empty():
		ctx["error"] = Types.ERR_PROMPT_NOT_FOUND
		return state
	match String(pr["kind"]):
		Types.PROMPT_MANA_FOCUS:
			return use_mana_focus(state, ctx)
		PROMPT_ELIXIR_TRANSMUTATION:
			return use_elixir_transmutation(state, ctx)
	ctx["error"] = Types.ERR_INVALID_CHOICE
	return state


## HOOK_USE_EVENT: extra.mana = k (0..min(daño, maná)) → paga k💧 y recibe el resto.
static func use_mana_focus(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var pr: Dictionary = (ctx["extra"] as Dictionary).get("prompt", {})
	if pr.is_empty() or String(pr["kind"]) != Types.PROMPT_MANA_FOCUS:
		ctx["error"] = Types.ERR_PROMPT_NOT_FOUND
		return state
	var pid: String = ctx["caster"]
	var p: Dictionary = Types.get_player(state, pid)
	var data: Dictionary = pr["data"]
	var damage: int = int(data.get("damage", 0))
	var raw: Variant = (ctx["extra"] as Dictionary).get("mana", -1)
	if not (raw is int) or int(raw) < 0 or int(raw) > mini(damage, int(p["mana"])):
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	var k: int = raw
	var events: Array = ctx["events"]
	if k > 0:
		Damage.pay_mana(state, pid, k)
		events.append(Types.make_log_entry(Types.LOG_MANA_CHANGED, Damage.turn_no(state), pid,
			{"target": pid, "delta": -k, "missing": 0, "card_id": Types.CARD_MANA_FOCUS}))
	var loss: Dictionary = (data.get("loss", {}) as Dictionary).duplicate(true)
	loss["amount"] = damage - k
	ArtifactEffects.apply_deferred_loss(state, pid, loss, events)
	return state


## HOOK_PROMPT (DECLINE): recibe todo el daño aplazado.
static func prompt_mana_focus(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var a: Dictionary = ctx["action"]
	if String(a["type"]) != Types.ACTION_DECLINE:
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	var pr: Dictionary = (ctx["extra"] as Dictionary)["prompt"]
	ArtifactEffects.apply_deferred_loss(state, String(ctx["caster"]),
		(pr["data"] as Dictionary).get("loss", {}), ctx["events"])
	return state


# =============================================================================
# Blessing, Warp Discharge
# =============================================================================

static func blessing(state: Dictionary, ctx: Dictionary) -> Dictionary:
	for pid: String in Types.alive_ids(state):
		Damage.heal(state, pid, BLESSING_HP, ctx["events"], "", Types.CARD_BLESSING)
	return state


static func warp_discharge(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var alive: Array[String] = Types.alive_ids(state)
	if alive.is_empty():
		return state
	var low: int = -1
	for pid: String in alive:
		var m: int = Types.get_player(state, pid)["mana"]
		if low < 0 or m < low:
			low = m
	var losers: Array[String] = []
	var winners: Array[String] = []
	for pid: String in alive:
		if int(Types.get_player(state, pid)["mana"]) == low:
			losers.append(pid)
		else:
			winners.append(pid)
	var events: Array = ctx["events"]
	events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), "",
		{"card_id": Types.CARD_WARP_DISCHARGE, "what": "lowest_mana", "targets": Array(losers), "mana": low}))
	for pid: String in losers:
		Damage.apply(state, Types.make_mod_event(Damage.KIND_DAMAGE, WARP_HP, "", pid, Types.ELEMENT_NONE,
			Types.CARD_WARP_DISCHARGE), events)
	for pid: String in winners:
		Damage.heal(state, pid, WARP_HP, events, "", Types.CARD_WARP_DISCHARGE)
	return state


# =============================================================================
# Elixir Transmutation
# =============================================================================

static func elixir_transmutation(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var max_hp: int = int((state["config"] as Dictionary)["max_hp"])
	for pid: String in turn_order_from(state, String(ctx["caster"])):
		var p: Dictionary = Types.get_player(state, pid)
		if int(p["hp"]) >= max_hp:
			continue
		(state["pending"] as Array).append(Types.make_prompt(Types.next_seq(state), pid,
			PROMPT_ELIXIR_TRANSMUTATION, {"price": ELIXIR_PRICE, "max": max_hp - int(p["hp"])},
			Types.CARD_ELIXIR_TRANSMUTATION, true))
	return state


## Cuántos 💖 puede comprar pid ahora (vida hasta el máximo y maná).
static func elixir_max(state: Dictionary, pid: String) -> int:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]):
		return 0
	var room: int = int((state["config"] as Dictionary)["max_hp"]) - int(p["hp"])
	@warning_ignore("integer_division")
	var affordable: int = int(p["mana"]) / ELIXIR_PRICE
	return maxi(0, mini(room, affordable))


## HOOK_USE_EVENT: extra.amount = n💖 a comprar (prompt obligatorio).
static func use_elixir_transmutation(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var pr: Dictionary = (ctx["extra"] as Dictionary).get("prompt", {})
	if pr.is_empty() or String(pr["kind"]) != PROMPT_ELIXIR_TRANSMUTATION:
		ctx["error"] = Types.ERR_PROMPT_NOT_FOUND
		return state
	var pid: String = ctx["caster"]
	var raw: Variant = (ctx["extra"] as Dictionary).get("amount", -1)
	if not (raw is int) or int(raw) < 0 or int(raw) > elixir_max(state, pid):
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	var n: int = raw
	var events: Array = ctx["events"]
	var got: int = Damage.heal(state, pid, n, events, pid, Types.CARD_ELIXIR_TRANSMUTATION)
	var paid: int = Damage.pay_mana(state, pid, got * ELIXIR_PRICE)
	events.append(Types.make_log_entry(Types.LOG_MANA_CHANGED, Damage.turn_no(state), pid,
		{"target": pid, "delta": -paid, "missing": 0, "card_id": Types.CARD_ELIXIR_TRANSMUTATION}))
	return state


## HOOK_LEGAL_ACTIONS (como `source` del prompt): USE_EVENT {amount:1..máx}.
static func legal_elixir_transmutation(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var card: Dictionary = ctx["card"]
	var pr: Dictionary = (card.get("data", {}) as Dictionary).get("prompt", {})
	if pr.is_empty() or String(pr["kind"]) != PROMPT_ELIXIR_TRANSMUTATION:
		return state
	if (state["active_event"] as Dictionary).is_empty():
		return state  # USE_EVENT necesita un evento activo al que enrutar
	var pid: String = ctx["caster"]
	var out: Array = ctx["actions"]
	for n: int in range(1, elixir_max(state, pid) + 1):
		out.append(Types.make_action_use_event(pid, {"amount": n}, int(pr["id"])))
	return state


# =============================================================================
# Utilidades
# =============================================================================

## Magos vivos en orden de turno empezando por `first` (si está vivo).
static func turn_order_from(state: Dictionary, first: String) -> Array[String]:
	var alive: Array[String] = Types.alive_ids(state)
	var i: int = maxi(0, alive.find(first))
	var out: Array[String] = []
	for k: int in alive.size():
		out.append(alive[(i + k) % alive.size()])
	return out


static func _mod(ctx: Dictionary, suffix: String, stage: String, op: String, value: int, element: String) -> Dictionary:
	var card: Dictionary = ctx["card"]
	var iid: int = card["iid"]
	var cid: String = card["card_id"]
	return Types.make_modifier("%s#%d%s" % [cid, iid, suffix], stage, op, value, "", Types.SIDE_ANY, element,
		Types.EXPIRES_NEXT_EVENT, cid, iid)
