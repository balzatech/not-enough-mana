class_name DefensiveEffects
extends RefCounted
## Defensivas (T6b) y Force Field. Firma: static func id(state, ctx) -> Dictionary.
##
## Las defensivas solo se juegan con REACT dentro de la ventana de reacción
## (reactions.gd). Al resolverse (LIFO) ctx.is_response = true y ctx.spell es
## la respuesta; ctx.spell.data.spell_iid = iid del hechizo original, al que se
## ligan los modificadores (expires = spell: caducan al resolverse o anularse).
##
##  Magic Shield  target = mago protegido. prevent, sub 2, solo daño de hechizo.
##  Frozen Bunny  target = mago protegido. prevent, prevent_all.
##  Mirror Shield target = destino (cualquier mago vivo, sin Force Field);
##                extra.protect = mago protegido (por defecto quien la juega).
##                redirect, hasta 2.
##  Last Wish     sin objetivo, protege a quien la juega. after_damage custom
##                "last_wish": si el daño del hechizo de un oponente lo elimina,
##                el atacante recibe el mismo daño (no es daño de hechizo).
##  Magic Capture roba la carta de arriba del descarte al resolverse (sin contar
##                las cartas con las que se pagó esta Magic Capture).
##  Annihilation  target_card = carta en mesa, el hechizo en curso o una
##                respuesta apilada. En mesa: sale (HOOK_LEAVE_PLAY /
##                HOOK_EVENT_END, se quitan sus modificadores) y va al descarte.
##                En la ventana: se marca cancelled.
##  Force Field   (hechizo de soporte) flags.force_field = lanzador en el objetivo.
##                Damage/Game ya aplican la inmunidad y la quitan al empezar el
##                turno del lanzador.

const HANDLER_LAST_WISH: String = "last_wish"
## Defensivas que leen ctx.targets[0] (exigen un mago objetivo).
const NEEDS_TARGET: Array[String] = [Types.CARD_MAGIC_SHIELD, Types.CARD_FROZEN_BUNNY, Types.CARD_MIRROR_SHIELD]

## Log del daño de Last Wish: el handler de modificadores no recibe `events`,
## así que lo deja aquí y Reactions.close() lo vuelca en los eventos de la
## acción (se vacía en cada cierre; nunca persiste entre reduce()).
static var _side_events: Array = []


static func drain_side_events() -> Array:
	var out: Array = _side_events.duplicate()
	_side_events.clear()
	return out


# =============================================================================
# Validación al jugar (la llama Reactions.check_react; no muta el estado)
# =============================================================================

static func check_response(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var card: Dictionary = ctx["card"]
	var targets: Array = ctx["targets"]
	var extra: Dictionary = ctx["extra"]
	if NEEDS_TARGET.has(String(card["card_id"])) and targets.is_empty():
		ctx["error"] = Types.ERR_INVALID_TARGET  # catálogo con target "none": no indexar targets[0]
		return state
	match String(card["card_id"]):
		Types.CARD_MIRROR_SHIELD:
			var dest: Dictionary = Types.get_player(state, String(targets[0]))
			if String((dest["flags"] as Dictionary)["force_field"]) != "":
				ctx["error"] = Types.ERR_TARGET_IMMUNE
				return state
			if extra.has("protect"):
				var pv: Variant = extra["protect"]
				if not (pv is String) or not Types.alive_ids(state).has(String(pv)):
					ctx["error"] = Types.ERR_INVALID_TARGET
					return state
		Types.CARD_ANNIHILATION:
			var tc: int = ctx["target_card"]
			var sp: Dictionary = Reactions.find_spell(state, tc)
			if not sp.is_empty() and bool(sp["cancelled"]):
				ctx["error"] = Types.ERR_INVALID_TARGET
				return state
	return state


## Variantes de `extra` que legal_actions ofrece para una carta.
static func extra_options(state: Dictionary, pid: String, card_id: String) -> Array:
	var out: Array = [{}]
	if card_id != Types.CARD_MIRROR_SHIELD:
		return out
	var main: Dictionary = (state["reaction"] as Dictionary).get("spell", {})
	if main.is_empty():
		return out
	for t: Variant in main["targets"]:
		var tid: String = t
		if tid != pid and Types.alive_ids(state).has(tid):
			out.append({"protect": tid})
	return out


# =============================================================================
# Efectos (al resolverse la respuesta)
# =============================================================================

static func magic_shield(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _protect(state, ctx, Types.OP_SUB, 2)


static func frozen_bunny(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _protect(state, ctx, Types.OP_PREVENT_ALL, 0)


static func mirror_shield(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var spell_iid: int = _spell_iid(ctx)
	if spell_iid < 0:
		ctx["error"] = Types.ERR_CARD_NOT_PLAYABLE
		return state
	if (ctx["targets"] as Array).is_empty():
		ctx["error"] = Types.ERR_INVALID_TARGET
		return state
	var dest: String = (ctx["targets"] as Array)[0]
	var protect: String = String((ctx["extra"] as Dictionary).get("protect", ctx["caster"]))
	if not _alive(state, dest) or not _alive(state, protect):
		_log(state, ctx, protect, "fizzled")
		return state
	var card: Dictionary = ctx["card"]
	var m: Dictionary = _mod(card, Types.STAGE_REDIRECT, Types.OP_REDIRECT, 2, protect, spell_iid)
	m["data"] = {"to": dest}
	Modifiers.add(state, m)
	_log(state, ctx, protect, "mirror_shield", {"to": dest})
	return state


static func last_wish(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var spell_iid: int = _spell_iid(ctx)
	if spell_iid < 0:
		ctx["error"] = Types.ERR_CARD_NOT_PLAYABLE
		return state
	var owner: String = ctx["caster"]
	var m: Dictionary = _mod(ctx["card"] as Dictionary, Types.STAGE_AFTER_DAMAGE, Types.OP_CUSTOM, 0, owner, spell_iid)
	m["handler"] = HANDLER_LAST_WISH
	Modifiers.add(state, m)
	_log(state, ctx, owner, "last_wish")
	return state


static func magic_capture(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var pid: String = ctx["caster"]
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]):
		return state
	var payment: Array = ctx["payment"]
	var discard: Array = state["discard"]
	for i: int in range(discard.size() - 1, -1, -1):
		var c: Dictionary = discard[i]
		if payment.has(int(c["iid"])):
			continue
		discard.remove_at(i)
		(p["hand"] as Array).append(c)
		_log(state, ctx, pid, "magic_capture", {"iid": int(c["iid"]), "stolen_card_id": String(c["card_id"])})
		return state
	_log(state, ctx, pid, "fizzled")
	return state


static func annihilation(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var iid: int = ctx["target_card"]
	var caster: String = ctx["caster"]
	var sp: Dictionary = Reactions.find_spell(state, iid)
	if not sp.is_empty():
		sp["cancelled"] = true
		_log(state, ctx, caster, "annihilation", {"iid": iid, "target_card_id": String((sp["card"] as Dictionary)["card_id"]), "zone": "reaction"})
		return state
	var found: Dictionary = Deck.find_in_play(state, iid)
	if found.is_empty():
		_log(state, ctx, caster, "fizzled")
		return state
	var tc: Dictionary = found["card"]
	var card_id: String = tc["card_id"]
	var zone: String = found["zone"]
	var events: Array = ctx["events"]
	if zone == "event":
		var end_fn: Callable = EffectRegistry.get_hook(Types.HOOK_EVENT_END, card_id)
		if end_fn.is_valid():
			state = _run_hook(end_fn, state, tc, caster, events)
		var ev: Dictionary = state["active_event"]
		if not ev.is_empty() and int(ev["iid"]) == iid:
			state["active_event"] = {}
	else:
		var leave_fn: Callable = EffectRegistry.get_hook(Types.HOOK_LEAVE_PLAY, card_id)
		if leave_fn.is_valid():
			state = _run_hook(leave_fn, state, tc, caster, events)
		var owner_p: Dictionary = Types.get_player(state, String(found["owner"]))
		var pile: Array = owner_p[zone]
		for i: int in pile.size():
			if int((pile[i] as Dictionary)["iid"]) == iid:
				pile.remove_at(i)
				break
	Modifiers.remove_by_source(state, iid)
	if not Types.all_card_iids(state).has(iid):
		Deck.to_discard(state, Types.make_card_instance(iid, card_id))
	_log(state, ctx, caster, "annihilation", {"iid": iid, "target_card_id": card_id, "zone": zone,
		"owner": String(found["owner"])})
	return state


static func force_field(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var caster: String = ctx["caster"]
	for t: Variant in ctx["targets"]:
		var p: Dictionary = Types.get_player(state, String(t))
		if p.is_empty() or bool(p["eliminated"]):
			continue
		(p["flags"] as Dictionary)["force_field"] = caster
		_log(state, ctx, String(t), "force_field", {"caster": caster})
	return state


# =============================================================================
# Handler de modificador (Last Wish)
# =============================================================================

static func mod_last_wish(state: Dictionary, mod: Dictionary, event: Dictionary) -> Dictionary:
	if String(event["kind"]) != Damage.KIND_DAMAGE or not bool(event["is_spell"]):
		return event
	var owner: String = mod["owner"]
	var attacker: String = event["source"]
	if attacker == "" or attacker == owner or String(event["target"]) != owner:
		return event
	var p: Dictionary = Types.get_player(state, owner)
	if p.is_empty() or not bool(p["eliminated"]) or String(p["eliminated_reason"]) != Types.ELIM_HP:
		return event
	var data: Dictionary = mod["data"]
	if bool(data.get("used", false)):
		return event
	data["used"] = true
	var amount: int = int(event["amount"])
	_side_events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), owner,
		{"card_id": Types.CARD_LAST_WISH, "what": "last_wish", "target": attacker, "amount": amount}))
	var ev: Dictionary = Types.make_mod_event(Damage.KIND_DAMAGE, amount, owner, attacker,
		Types.ELEMENT_NONE, Types.CARD_LAST_WISH, -1, false)
	Damage.resolve(state, ev, _side_events)
	return event


# =============================================================================
# Internos
# =============================================================================

static func _protect(state: Dictionary, ctx: Dictionary, op: String, value: int) -> Dictionary:
	var spell_iid: int = _spell_iid(ctx)
	if spell_iid < 0:
		ctx["error"] = Types.ERR_CARD_NOT_PLAYABLE
		return state
	if (ctx["targets"] as Array).is_empty():
		ctx["error"] = Types.ERR_INVALID_TARGET
		return state
	var target: String = (ctx["targets"] as Array)[0]
	if not _alive(state, target):
		_log(state, ctx, target, "fizzled")
		return state
	Modifiers.add(state, _mod(ctx["card"] as Dictionary, Types.STAGE_PREVENT, op, value, target, spell_iid))
	_log(state, ctx, target, String((ctx["card"] as Dictionary)["card_id"]))
	return state


static func _mod(card: Dictionary, stage: String, op: String, value: int, owner: String, spell_iid: int) -> Dictionary:
	var card_id: String = card["card_id"]
	var iid: int = card["iid"]
	var m: Dictionary = Types.make_modifier("%s#%d" % [card_id, iid], stage, op, value, owner,
		Types.SIDE_TARGET, "", Types.EXPIRES_SPELL, card_id, iid)
	m["spell_only"] = true
	m["spell_iid"] = spell_iid
	return m


static func _spell_iid(ctx: Dictionary) -> int:
	var sp: Dictionary = ctx["spell"]
	if not bool(ctx["is_response"]) or sp.is_empty():
		return -1
	return int((sp["data"] as Dictionary).get("spell_iid", -1))


static func _alive(state: Dictionary, pid: String) -> bool:
	var p: Dictionary = Types.get_player(state, pid)
	return not p.is_empty() and not bool(p["eliminated"])


static func _run_hook(fn: Callable, state: Dictionary, tc: Dictionary, actor: String, events: Array) -> Dictionary:
	var hctx: Dictionary = Types.make_effect_ctx(tc, CardCatalog.get_def(String(tc["card_id"])), actor)
	hctx["events"] = events
	var ret: Variant = fn.call(state, hctx)
	if ret is Dictionary and not (ret as Dictionary).is_empty():
		return ret
	return state


static func _log(state: Dictionary, ctx: Dictionary, target: String, what: String, extra: Dictionary = {}) -> void:
	var data: Dictionary = {"card_id": String((ctx["card"] as Dictionary)["card_id"]), "what": what, "target": target}
	data.merge(extra, true)
	(ctx["events"] as Array).append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), String(ctx["caster"]), data))
