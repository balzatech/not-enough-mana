class_name ArtifactEffects
extends RefCounted
## Artefactos (T6c). Firma: static func id(state: Dictionary, ctx: Dictionary) -> Dictionary
##
## Al resolverse un artefacto, Game.resolve_spell ya lo ha puesto en
## player.artifacts; el efecto solo REGISTRA modificadores en la tubería
## (Modifiers) con expires = while_in_play y source_iid = iid del artefacto, de
## modo que Annihilation (Modifiers.remove_by_source) los retira sin conocerlos.
##
##  * Tiara / Boots / Cloak: incoming, sub 1, elemento, side target, solo hechizos.
##  * Wild Fire / Dragon Glass / Tesla Coil: outgoing, add 1, elemento, side
##    source, solo hechizos.
##  * Spellbook: hand_limit +1 (side target). Máx. 1 por mago (HOOK_CAN_PLAY).
##  * Runic Armor: prevent, custom "runic_armor": anula toda pérdida cuyo
##    card_id sea una maldición (incluye BREAK_RULE de Curse of Rules).
##  * Magic Cap: custom "magic_cap" al final de prevent/redirect: aplaza la
##    pérdida (💖 o 💧) y abre PROMPT_USE_MAGIC_CAP. USE_ARTIFACT → se descarta
##    el Cap y la pérdida no ocurre; DECLINE → se aplica (apply_deferred_loss).
##  * Scroll of Elements: comodín de pago (HOOK_PAY_WILDCARD), un uso.
##  * Transformation Glove / Twardowsky's Mirror: USE_ARTIFACT una vez por turno,
##    solo en tu turno (fase principal, sin prompts ni reacción). Lo visto con
##    Mirror va a state.reveals[pid] (privado).

const HANDLER_MAGIC_CAP: String = "magic_cap"
const HANDLER_RUNIC_ARMOR: String = "runic_armor"

## Prioridad de los modificadores que aplazan una pérdida: deben ir DESPUÉS de
## las defensivas (prioridad 0). Mana Focus (EventEffects) usa 1000.
const PRIORITY_MAGIC_CAP: int = 1001

const BONUS: int = 1
const PROTECTION: int = 1


# =============================================================================
# Protección elemental
# =============================================================================

static func fireproof_tiara(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _protection(state, ctx, Types.ELEMENT_FIRE)


static func padded_boots(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _protection(state, ctx, Types.ELEMENT_ICE)


static func faradays_cloak(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _protection(state, ctx, Types.ELEMENT_ELECTRIC)


static func _protection(state: Dictionary, ctx: Dictionary, element: String) -> Dictionary:
	var m: Dictionary = _mod(ctx, "", Types.STAGE_INCOMING, Types.OP_SUB, PROTECTION, Types.SIDE_TARGET, element)
	m["spell_only"] = true
	Modifiers.add(state, m)
	return state


# =============================================================================
# Bonos elementales
# =============================================================================

static func wild_fire(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _bonus(state, ctx, Types.ELEMENT_FIRE)


static func dragon_glass(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _bonus(state, ctx, Types.ELEMENT_ICE)


static func tesla_coil(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _bonus(state, ctx, Types.ELEMENT_ELECTRIC)


static func _bonus(state: Dictionary, ctx: Dictionary, element: String) -> Dictionary:
	var m: Dictionary = _mod(ctx, "", Types.STAGE_OUTGOING, Types.OP_ADD, BONUS, Types.SIDE_SOURCE, element)
	m["spell_only"] = true
	Modifiers.add(state, m)
	return state


# =============================================================================
# Spellbook
# =============================================================================

static func spellbook(state: Dictionary, ctx: Dictionary) -> Dictionary:
	Modifiers.add(state, _mod(ctx, "", Types.STAGE_HAND_LIMIT, Types.OP_ADD, 1, Types.SIDE_TARGET, ""))
	return state


## HOOK_CAN_PLAY: no se puede tener más de un Spellbook.
static func can_play_spellbook(state: Dictionary, ctx: Dictionary) -> Dictionary:
	if has_artifact(state, String(ctx["caster"]), Types.CARD_SPELLBOOK):
		ctx["error"] = Types.ERR_ARTIFACT_LIMIT
	return state


# =============================================================================
# Runic Armor
# =============================================================================

static func runic_armor(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var m: Dictionary = _mod(ctx, "", Types.STAGE_PREVENT, Types.OP_CUSTOM, 0, Types.SIDE_TARGET, "")
	m["handler"] = HANDLER_RUNIC_ARMOR
	Modifiers.add(state, m)
	return state


## Handler OP_CUSTOM: previene entera cualquier pérdida causada por una maldición.
static func mod_runic_armor(_state: Dictionary, _mod_d: Dictionary, ev: Dictionary) -> Dictionary:
	if not is_curse(String(ev["card_id"])) or int(ev["amount"]) <= 0:
		return ev
	ev["prevented"] = int(ev["prevented"]) + int(ev["amount"])
	ev["amount"] = 0
	(ev["data"] as Dictionary)["immune"] = Types.CARD_RUNIC_ARMOR
	return ev


static func is_curse(card_id: String) -> bool:
	if card_id == "":
		return false
	return String(CardCatalog.get_def(card_id).get("type", "")) == Types.CARD_TYPE_CURSE


# =============================================================================
# Magic Cap
# =============================================================================

static func magic_cap(state: Dictionary, ctx: Dictionary) -> Dictionary:
	# Pérdida de maná (solo pasa por prevent) y daño redirigido (incoming+prevent).
	var a: Dictionary = _mod(ctx, "/p", Types.STAGE_PREVENT, Types.OP_CUSTOM, 0, Types.SIDE_TARGET, "")
	a["handler"] = HANDLER_MAGIC_CAP
	a["priority"] = PRIORITY_MAGIC_CAP
	Modifiers.add(state, a)
	# Daño normal: al final de redirect (tras Mirror Shield).
	var b: Dictionary = _mod(ctx, "", Types.STAGE_REDIRECT, Types.OP_CUSTOM, 0, Types.SIDE_TARGET, "")
	b["handler"] = HANDLER_MAGIC_CAP
	b["priority"] = PRIORITY_MAGIC_CAP
	Modifiers.add(state, b)
	return state


## Handler OP_CUSTOM: aplaza la pérdida y pregunta al dueño si usa el Cap.
static func mod_magic_cap(state: Dictionary, mod_d: Dictionary, ev: Dictionary) -> Dictionary:
	if not is_deferrable(ev, String(mod_d["stage"])):
		return ev
	var owner: String = mod_d["owner"]
	var cap_iid: int = mod_d["source_iid"]
	for pr: Variant in state["pending"]:
		var prd: Dictionary = pr
		if String(prd["kind"]) == Types.PROMPT_USE_MAGIC_CAP \
				and int((prd["data"] as Dictionary).get("cap_iid", -1)) == cap_iid:
			return ev
	(state["pending"] as Array).append(Types.make_prompt(Types.next_seq(state), owner,
		Types.PROMPT_USE_MAGIC_CAP, {"loss": loss_snapshot(ev), "cap_iid": cap_iid}, Types.CARD_MAGIC_CAP, true))
	return defer(ev, Types.CARD_MAGIC_CAP)


## HOOK_USE: el dueño descarta el Cap y evita la pérdida aplazada.
static func use_magic_cap(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var pr: Dictionary = (ctx["extra"] as Dictionary).get("prompt", {})
	if pr.is_empty() or String(pr["kind"]) != Types.PROMPT_USE_MAGIC_CAP:
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	var pid: String = ctx["caster"]
	var card: Dictionary = ctx["card"]
	discard_artifact(state, pid, int(card["iid"]))
	var loss: Dictionary = (pr["data"] as Dictionary).get("loss", {})
	(ctx["events"] as Array).append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), pid, {
		"card_id": Types.CARD_MAGIC_CAP, "what": "loss_avoided",
		"kind": String(loss.get("kind", "")), "amount": int(loss.get("amount", 0)),
	}))
	return state


## HOOK_PROMPT (DECLINE): no usa el Cap; la pérdida se aplica ahora.
static func prompt_magic_cap(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var a: Dictionary = ctx["action"]
	if String(a["type"]) != Types.ACTION_DECLINE:
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	var pr: Dictionary = (ctx["extra"] as Dictionary)["prompt"]
	apply_deferred_loss(state, String(ctx["caster"]), (pr["data"] as Dictionary).get("loss", {}), ctx["events"])
	return state


## HOOK_LEGAL_ACTIONS: USE_ARTIFACT de este Cap para cada prompt de Cap pendiente.
static func legal_magic_cap(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var card: Dictionary = ctx["card"]
	if int(card["iid"]) < 0:
		return state  # llamada como `source` de un prompt: ya se cubre desde el artefacto
	var pid: String = ctx["caster"]
	var out: Array = ctx["actions"]
	for pr: Variant in state["pending"]:
		var prd: Dictionary = pr
		if String(prd["player"]) == pid and String(prd["kind"]) == Types.PROMPT_USE_MAGIC_CAP:
			out.append(Types.make_action_use_artifact(pid, int(card["iid"]), [], [], {}, int(prd["id"])))
	return state


# =============================================================================
# Pérdidas aplazadas (Magic Cap, Mana Focus)
# =============================================================================

## ¿Este evento es una pérdida que se puede aplazar en esta etapa? El daño
## normal se aplaza en redirect (tras Mirror Shield); el daño redirigido y la
## pérdida de maná, en prevent (son las únicas etapas que recorren).
static func is_deferrable(ev: Dictionary, stage: String) -> bool:
	if int(ev["amount"]) <= 0:
		return false
	var kind: String = ev["kind"]
	if kind == Damage.KIND_DAMAGE:
		var redirected: bool = (ev["data"] as Dictionary).has("redirected_from")
		return stage == Types.STAGE_REDIRECT or (stage == Types.STAGE_PREVENT and redirected)
	return kind == Damage.KIND_MANA_LOSS and stage == Types.STAGE_PREVENT


## Datos JSON de la pérdida para guardarla en un prompt.
static func loss_snapshot(ev: Dictionary) -> Dictionary:
	return {
		"kind": String(ev["kind"]), "amount": int(ev["amount"]), "source": String(ev["source"]),
		"target": String(ev["target"]), "element": String(ev["element"]), "card_id": String(ev["card_id"]),
		"spell_iid": int(ev["spell_iid"]), "is_spell": bool(ev["is_spell"]),
	}


## Deja el evento a 0 marcándolo como aplazado (no cuenta como prevenido).
static func defer(ev: Dictionary, by_card: String) -> Dictionary:
	ev["amount"] = 0
	(ev["data"] as Dictionary)["deferred"] = by_card
	return ev


## Aplica una pérdida guardada con loss_snapshot(): el daño se pierde como vida
## (y pasa por after_damage, p. ej. Not Enough Mana); el maná, como pago con
## faltante (prompt de maná insuficiente). No vuelve a pasar por los
## modificadores previos (ya se aplicaron).
static func apply_deferred_loss(state: Dictionary, pid: String, loss: Dictionary, events: Array) -> void:
	var amount: int = int(loss.get("amount", 0))
	if amount <= 0:
		return
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]):
		return
	var source: String = loss.get("source", "")
	var card_id: String = loss.get("card_id", "")
	if String(loss.get("kind", "")) == Damage.KIND_MANA_LOSS:
		var paid: int = Damage.pay_mana(state, pid, amount)
		var missing: int = amount - paid
		events.append(Types.make_log_entry(Types.LOG_MANA_CHANGED, Damage.turn_no(state), source,
			{"target": pid, "delta": -paid, "missing": missing, "card_id": card_id}))
		if missing > 0:
			Damage.add_shortfall(state, pid, missing, card_id)
		return
	var lost: int = Damage.lose_hp(state, pid, amount, events, source, card_id)
	var ev: Dictionary = Types.make_mod_event(Damage.KIND_DAMAGE, amount, source, pid,
		String(loss.get("element", Types.ELEMENT_NONE)), card_id, int(loss.get("spell_iid", -1)),
		bool(loss.get("is_spell", false)))
	(ev["data"] as Dictionary)["dealt"] = lost
	(ev["data"] as Dictionary)["deferred_applied"] = true
	Modifiers.run_stage(state, Types.STAGE_AFTER_DAMAGE, ev)


# =============================================================================
# Scroll of Elements
# =============================================================================

## Al equiparse no hace nada: actúa como comodín de pago.
static func scroll_of_elements(state: Dictionary, _ctx: Dictionary) -> Dictionary:
	return state


## HOOK_PAY_WILDCARD: sustituye a cualquier carta requerida y se descarta al usarse.
static func pay_scroll_of_elements(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var mode: String = ctx.get("mode", "")
	if mode == "check":
		ctx["ok"] = true
		return state
	if mode == "consume":
		var card: Dictionary = ctx["card"]
		var pid: String = ctx["caster"]
		discard_artifact(state, pid, int(card["iid"]))
		var events: Array = ctx.get("events", [])
		var def: Dictionary = ctx.get("def", {})
		events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), pid,
			{"card_id": Types.CARD_SCROLL_OF_ELEMENTS, "what": "used_as_payment", "for": String(def.get("id", ""))}))
	return state


# =============================================================================
# Transformation Glove
# =============================================================================

## Al equiparse no hace nada: se activa con USE_ARTIFACT.
static func transformation_glove(state: Dictionary, _ctx: Dictionary) -> Dictionary:
	return state


## HOOK_USE: action.cards = [iid de la mano] → se descarta y se roba otra.
static func use_transformation_glove(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var pid: String = ctx["caster"]
	var tc: Dictionary = _check_once_per_turn(state, ctx)
	if tc.is_empty():
		return state
	var cards: Array = ctx["payment"]
	var p: Dictionary = Types.get_player(state, pid)
	if cards.size() != 1 or not (cards[0] is int):
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	var iid: int = cards[0]
	var c: Dictionary = Deck.take_from_hand(p, iid)
	if c.is_empty():
		ctx["error"] = Types.ERR_CARD_NOT_IN_HAND
		return state
	Deck.to_discard(state, c)
	(tc["data"] as Dictionary)["used_turn"] = Damage.turn_no(state)
	var events: Array = ctx["events"]
	events.append(Types.make_log_entry(Types.LOG_CARD_DISCARDED, Damage.turn_no(state), pid,
		{"cards": [iid], "card_ids": [String(c["card_id"])], "card_id": Types.CARD_TRANSFORMATION_GLOVE}))
	Game.draw_one(state, pid, events)
	return state


static func legal_transformation_glove(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var card: Dictionary = ctx["card"]
	var pid: String = ctx["caster"]
	if int(card["iid"]) < 0 or not _usable_now(state, pid, card):
		return state
	var out: Array = ctx["actions"]
	for c: Variant in Types.get_player(state, pid)["hand"]:
		out.append(Types.make_action_use_artifact(pid, int(card["iid"]), [], [int((c as Dictionary)["iid"])]))
	return state


# =============================================================================
# Twardowsky's Mirror
# =============================================================================

static func twardowskys_mirror(state: Dictionary, _ctx: Dictionary) -> Dictionary:
	return state


## HOOK_USE: mira la carta de arriba del mazo (solo la ve quien lo usa).
static func use_twardowskys_mirror(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var pid: String = ctx["caster"]
	var tc: Dictionary = _check_once_per_turn(state, ctx)
	if tc.is_empty():
		return state
	var events: Array = ctx["events"]
	if (state["deck"] as Array).is_empty():
		Deck.reshuffle_discard(state, events)
	var deck: Array = state["deck"]
	if deck.is_empty():
		ctx["error"] = Types.ERR_INVALID_ACTION
		return state
	var top: Dictionary = deck[deck.size() - 1]
	(tc["data"] as Dictionary)["used_turn"] = Damage.turn_no(state)
	add_reveal(state, pid, Types.make_reveal("deck_top", "", [top], Damage.turn_no(state)))
	events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), pid,
		{"card_id": Types.CARD_TWARDOWSKYS_MIRROR, "what": "peeked_deck"}))
	events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), pid,
		{"card_id": Types.CARD_TWARDOWSKYS_MIRROR, "what": "peeked_card", "iid": int(top["iid"]),
		"seen": String(top["card_id"])}, [pid]))
	return state


## HOOK_LEGAL_ACTIONS: se ofrece si quedan cartas en el mazo o en el descarte
## (al usarlo con el mazo vacío se baraja el descarte).
static func legal_twardowskys_mirror(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var card: Dictionary = ctx["card"]
	var pid: String = ctx["caster"]
	if int(card["iid"]) < 0 or not _usable_now(state, pid, card):
		return state
	# Contrato A1: solo datos públicos (tamaño del mazo, descarte). Funciona
	# igual sobre el estado y sobre una vista (deck vacío, deck_count real).
	if Types.deck_size(state) == 0 and (state["discard"] as Array).is_empty():
		return state
	(ctx["actions"] as Array).append(Types.make_action_use_artifact(pid, int(card["iid"])))
	return state


# =============================================================================
# Utilidades
# =============================================================================

## ¿pid tiene en mesa un artefacto card_id?
static func has_artifact(state: Dictionary, pid: String, card_id: String) -> bool:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty():
		return false
	for c: Variant in p["artifacts"]:
		if String((c as Dictionary)["card_id"]) == card_id:
			return true
	return false


## Quita un artefacto de la mesa de pid, lo manda al descarte y retira sus
## modificadores. Devuelve false si no estaba.
static func discard_artifact(state: Dictionary, pid: String, iid: int) -> bool:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty():
		return false
	var arts: Array = p["artifacts"]
	for i: int in arts.size():
		var c: Dictionary = arts[i]
		if int(c["iid"]) == iid:
			arts.remove_at(i)
			Deck.to_discard(state, Types.make_card_instance(iid, String(c["card_id"])))
			Modifiers.remove_by_source(state, iid)
			return true
	return false


## Añade una revelación privada a state.reveals[pid], sustituyendo la anterior
## del mismo tipo y origen (la información vieja ya no es fiable).
static func add_reveal(state: Dictionary, pid: String, reveal: Dictionary) -> void:
	var reveals: Dictionary = state["reveals"]
	var mine: Array = reveals.get(pid, [])
	var kept: Array = []
	for r: Variant in mine:
		var rd: Dictionary = r
		if not (String(rd["kind"]) == String(reveal["kind"]) and String(rd["of"]) == String(reveal["of"])):
			kept.append(rd)
	kept.append(reveal)
	reveals[pid] = kept


static func _mod(ctx: Dictionary, suffix: String, stage: String, op: String, value: int, side: String,
		element: String) -> Dictionary:
	var card: Dictionary = ctx["card"]
	var iid: int = card["iid"]
	var cid: String = card["card_id"]
	return Types.make_modifier("%s#%d%s" % [cid, iid, suffix], stage, op, value, String(ctx["caster"]),
		side, element, Types.EXPIRES_WHILE_IN_PLAY, cid, iid)


## Artefacto en mesa del que actúa (referencia al estado) si se puede usar
## ahora; si no, escribe ctx.error y devuelve {}.
static func _check_once_per_turn(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var pid: String = ctx["caster"]
	var card: Dictionary = ctx["card"]
	var e: String = Game.in_turn_error(state, pid)
	if e != Types.ERR_NONE:
		ctx["error"] = e
		return {}
	var tc: Dictionary = _own_table_card(state, pid, int(card["iid"]))
	if tc.is_empty():
		ctx["error"] = Types.ERR_CARD_NOT_IN_PLAY
		return {}
	if int((tc["data"] as Dictionary).get("used_turn", -1)) == Damage.turn_no(state):
		ctx["error"] = Types.ERR_ARTIFACT_ALREADY_USED
		return {}
	return tc


static func _usable_now(state: Dictionary, pid: String, card: Dictionary) -> bool:
	if Game.in_turn_error(state, pid) != Types.ERR_NONE:
		return false
	var data: Dictionary = card.get("data", {})
	return int(data.get("used_turn", -1)) != Damage.turn_no(state)


static func _own_table_card(state: Dictionary, pid: String, iid: int) -> Dictionary:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty():
		return {}
	for c: Variant in p["artifacts"]:
		var cd: Dictionary = c
		if int(cd["iid"]) == iid:
			return cd
	return {}
