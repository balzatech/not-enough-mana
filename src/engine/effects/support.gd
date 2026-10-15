class_name SupportEffects
extends RefCounted
## Soporte (T6c). Firma: static func id(state: Dictionary, ctx: Dictionary) -> Dictionary
## (Force Field es de T6b, en defensive.gd.)
##
##  * Heal / Greater Heal: +1💖 / +2💖 al objetivo (tope config.max_hp y pool).
##  * Book Exchange: intercambia la mano de quien la lanza con la del objetivo.
##  * Magic Hand: quien la lanza ve la mano del objetivo (state.reveals, PRIVADO)
##    y elige 1 carta con PROMPT_CHOOSE_CARD. Las iids de esa mano NO van en el
##    prompt (state.pending es público y las iids identifican la carta): el
##    prompt lleva data {from, count:1, cards:[], hidden:true}; la UI muestra
##    las cartas desde reveals y las acciones legales las añade
##    HOOK_LEGAL_ACTIONS, también desde reveals[caster] (contrato A1).
##  * Potent Elixir: flags.potent_elixir += 1 (Damage.potion_amount duplica).
##  * Space Shift: descarta toda la mano y roba hasta el límite (los eventos
##    que salgan se activan, como en un robo normal).

const HEAL_AMOUNT: int = 1
const GREATER_HEAL_AMOUNT: int = 2


static func heal(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _heal(state, ctx, HEAL_AMOUNT)


static func greater_heal(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _heal(state, ctx, GREATER_HEAL_AMOUNT)


static func _heal(state: Dictionary, ctx: Dictionary, amount: int) -> Dictionary:
	var card: Dictionary = ctx["card"]
	for t: Variant in ctx["targets"]:
		Damage.heal(state, String(t), amount, ctx["events"], String(ctx["caster"]), String(card["card_id"]))
	return state


# =============================================================================
# Book Exchange
# =============================================================================

static func book_exchange(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var caster: String = ctx["caster"]
	var target: String = (ctx["targets"] as Array)[0]
	var a: Dictionary = Types.get_player(state, caster)
	var b: Dictionary = Types.get_player(state, target)
	if b.is_empty() or bool(b["eliminated"]):
		return _fizzle(state, ctx)
	var ha: Array = a["hand"]
	var hb: Array = b["hand"]
	a["hand"] = hb
	b["hand"] = ha
	(ctx["events"] as Array).append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), caster, {
		"card_id": Types.CARD_BOOK_EXCHANGE, "what": "hands_exchanged", "target": target,
		"caster_count": hb.size(), "target_count": ha.size(),
	}))
	return state


# =============================================================================
# Magic Hand
# =============================================================================

static func magic_hand(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var caster: String = ctx["caster"]
	var target: String = (ctx["targets"] as Array)[0]
	var b: Dictionary = Types.get_player(state, target)
	if b.is_empty() or bool(b["eliminated"]):
		return _fizzle(state, ctx)
	var hand: Array = b["hand"]
	var turn: int = Damage.turn_no(state)
	ArtifactEffects.add_reveal(state, caster, Types.make_reveal("hand", target, hand, turn))
	var events: Array = ctx["events"]
	var ids: Array = []
	for c: Variant in hand:
		ids.append(String((c as Dictionary)["card_id"]))
	events.append(Types.make_log_entry(Types.LOG_EFFECT, turn, caster,
		{"card_id": Types.CARD_MAGIC_HAND, "what": "hand_seen", "target": target, "count": hand.size()}))
	events.append(Types.make_log_entry(Types.LOG_EFFECT, turn, caster,
		{"card_id": Types.CARD_MAGIC_HAND, "what": "hand_cards", "target": target, "seen": ids}, [caster]))
	if hand.is_empty():
		return state
	(state["pending"] as Array).append(Types.make_prompt(Types.next_seq(state), caster,
		Types.PROMPT_CHOOSE_CARD, {"from": target, "count": 1, "cards": [], "hidden": true},
		Types.CARD_MAGIC_HAND, false))
	return state


## HOOK_PROMPT: CHOOSE_CARDS [iid] de la mano de data.from → pasa a la mano del
## que lanzó Magic Hand.
static func prompt_magic_hand(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var a: Dictionary = ctx["action"]
	if String(a["type"]) != Types.ACTION_CHOOSE_CARDS:
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	var pr: Dictionary = (ctx["extra"] as Dictionary)["prompt"]
	var from: String = (pr["data"] as Dictionary).get("from", "")
	var cards: Array = a["cards"]
	var victim: Dictionary = Types.get_player(state, from)
	var pid: String = ctx["caster"]
	if victim.is_empty() or cards.size() != 1 or not (cards[0] is int):
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	var c: Dictionary = Deck.take_from_hand(victim, int(cards[0]))
	if c.is_empty():
		ctx["error"] = Types.ERR_INVALID_CHOICE
		return state
	(Types.get_player(state, pid)["hand"] as Array).append(c)
	var turn: int = Damage.turn_no(state)
	var events: Array = ctx["events"]
	events.append(Types.make_log_entry(Types.LOG_EFFECT, turn, pid,
		{"card_id": Types.CARD_MAGIC_HAND, "what": "card_stolen", "target": from}))
	events.append(Types.make_log_entry(Types.LOG_EFFECT, turn, pid,
		{"card_id": Types.CARD_MAGIC_HAND, "what": "card_stolen_detail", "target": from,
		"iid": int(c["iid"]), "stolen": String(c["card_id"])}, [pid, from]))
	return state


## HOOK_LEGAL_ACTIONS (como `source` del prompt): una CHOOSE_CARDS por carta.
## Contrato A1: las cartas salen de lo que vio quien lanzó Magic Hand
## (reveals[caster], kind "hand", of = data.from), no de la mano real de la
## víctima, así que el resultado es el mismo sobre el estado y sobre la vista
## del que elige. Se descartan las cartas que ya están en una zona pública
## (p. ej. la víctima las descartó por otro prompt): ya no están en su mano.
## La validación de CHOOSE_CARDS (prompt_magic_hand) sigue mirando la mano real.
static func legal_magic_hand(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var card: Dictionary = ctx["card"]
	var pr: Dictionary = (card.get("data", {}) as Dictionary).get("prompt", {})
	if pr.is_empty() or String(pr["kind"]) != Types.PROMPT_CHOOSE_CARD:
		return state
	var data: Dictionary = pr["data"]
	if not bool(data.get("hidden", false)):
		return state
	var from: String = data.get("from", "")
	var victim: Dictionary = Types.get_player(state, from)
	if victim.is_empty() or bool(victim["eliminated"]):
		return state
	var caster: String = ctx["caster"]
	var gone: Array = public_iids(state)
	var out: Array = ctx["actions"]
	for c: Variant in revealed_hand(state, caster, from):
		var iid: int = int((c as Dictionary)["iid"])
		if not gone.has(iid):
			out.append(Types.make_action_choose_cards(caster, int(pr["id"]), [iid]))
	return state


## Última mano revelada (kind "hand") de `of` en reveals[viewer]. [] si no hay.
## Solo lee reveals[viewer]: vale sobre el estado y sobre la vista de viewer.
static func revealed_hand(state: Dictionary, viewer: String, of: String) -> Array:
	var reveals: Array = (state.get("reveals", {}) as Dictionary).get(viewer, []) as Array
	for i: int in range(reveals.size() - 1, -1, -1):
		var r: Dictionary = reveals[i]
		if String(r.get("kind", "")) == "hand" and String(r.get("of", "")) == of:
			return r.get("cards", []) as Array
	return []


## iids de las cartas en zonas públicas: descarte, mesas y evento activo.
static func public_iids(state: Dictionary) -> Array:
	var out: Array = []
	for c: Variant in state["discard"]:
		out.append(int((c as Dictionary)["iid"]))
	for p: Variant in state["players"]:
		var pd: Dictionary = p
		for zone: String in ["artifacts", "curses"]:
			for c: Variant in pd[zone]:
				out.append(int((c as Dictionary)["iid"]))
	var ev: Dictionary = state["active_event"]
	if not ev.is_empty():
		out.append(int(ev["iid"]))
	return out


# =============================================================================
# Potent Elixir, Space Shift
# =============================================================================

static func potent_elixir(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var caster: String = ctx["caster"]
	var fl: Dictionary = Types.get_player(state, caster)["flags"]
	fl["potent_elixir"] = int(fl["potent_elixir"]) + 1
	(ctx["events"] as Array).append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), caster,
		{"card_id": Types.CARD_POTENT_ELIXIR, "what": "next_potion_doubled", "pending": int(fl["potent_elixir"])}))
	return state


static func space_shift(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var caster: String = ctx["caster"]
	var p: Dictionary = Types.get_player(state, caster)
	var hand: Array = p["hand"]
	var iids: Array = []
	var cids: Array = []
	for c: Variant in hand:
		var cd: Dictionary = c
		iids.append(int(cd["iid"]))
		cids.append(String(cd["card_id"]))
		Deck.to_discard(state, cd)
	hand.clear()
	var events: Array = ctx["events"]
	events.append(Types.make_log_entry(Types.LOG_CARD_DISCARDED, Damage.turn_no(state), caster,
		{"cards": iids, "card_ids": cids, "card_id": Types.CARD_SPACE_SHIFT}))
	Game.draw_up_to_limit(state, caster, events)
	return state


# =============================================================================
# Utilidades
# =============================================================================

static func _fizzle(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var card: Dictionary = ctx["card"]
	(ctx["events"] as Array).append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state),
		String(ctx["caster"]), {"card_id": String(card["card_id"]), "what": "fizzled"}))
	return state

