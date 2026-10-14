class_name Deck
extends RefCounted
## Mazo: construir, barajar (Fisher-Yates con Rng), robar y rebarajar el
## descarte (T4). Funciones puras sobre la copia de trabajo del estado: MUTAN
## `state` en sitio (convención del reducer).
##
## Pilas: la carta de ARRIBA es el ÚLTIMO elemento (pop_back / push_back).


## Instancias de todas las cartas jugables del catálogo `defs` (card_id -> def),
## con iids 1..N. Orden determinista: Types.PLAYABLE_CARD_IDS y después
## cualquier otro id jugable en orden alfabético. Respeta
## config.include_curse_of_rules.
static func build_instances(defs: Dictionary, cfg: Dictionary) -> Array:
	var ids: Array[String] = []
	for id: String in Types.PLAYABLE_CARD_IDS:
		if defs.has(id):
			ids.append(id)
	var extra: Array[String] = []
	for k: Variant in defs:
		var ks: String = str(k)
		if not ids.has(ks):
			extra.append(ks)
	extra.sort()
	ids.append_array(extra)
	var out: Array = []
	var iid: int = 1
	for id: String in ids:
		var d: Dictionary = defs[id]
		if not bool(d.get("playable", false)) or String(d.get("type", "")) == Types.CARD_TYPE_NON_PLAYABLE:
			continue
		if id == Types.CARD_CURSE_OF_RULES and not bool(cfg.get("include_curse_of_rules", true)):
			continue
		for _i: int in int(d.get("quantity", 0)):
			out.append(Types.make_card_instance(iid, id))
			iid += 1
	return out


## Fisher-Yates sobre state[key] con state.rng_state (avanza el RNG).
static func shuffle_pile(state: Dictionary, key: String = "deck") -> void:
	var r: Dictionary = Rng.shuffle(state[key] as Array, int(state["rng_state"]))
	state[key] = r["array"]
	state["rng_state"] = int(r["state"])


## Baraja el descarte y lo convierte en el mazo nuevo. Devuelve true si había
## cartas. Añade LOG_DECK_RESHUFFLED a `events`.
static func reshuffle_discard(state: Dictionary, events: Array) -> bool:
	var discard: Array = state["discard"]
	if discard.is_empty():
		return false
	var deck: Array = state["deck"]
	var moved: Array = discard.duplicate()
	discard.clear()
	moved.append_array(deck)
	state["deck"] = moved
	shuffle_pile(state, "deck")
	events.append(Types.make_log_entry(Types.LOG_DECK_RESHUFFLED, int((state["turn"] as Dictionary)["number"]),
		"", {"count": moved.size()}))
	return true


## Saca la carta de arriba del mazo (rebarajando el descarte si se acabó).
## Devuelve la instancia o {} si no quedan cartas en mazo ni descarte.
static func pop_top(state: Dictionary, events: Array) -> Dictionary:
	var deck: Array = state["deck"]
	if deck.is_empty():
		if not reshuffle_discard(state, events):
			return {}
		deck = state["deck"]
	var c: Dictionary = deck.pop_back()
	return c


## Pone una instancia encima del descarte.
static func to_discard(state: Dictionary, card: Dictionary) -> void:
	(state["discard"] as Array).append(card)


## Índice en la mano de pid de la carta con ese iid, o -1.
static func hand_index(player: Dictionary, iid: int) -> int:
	var hand: Array = player["hand"]
	for i: int in hand.size():
		var c: Dictionary = hand[i]
		if int(c["iid"]) == iid:
			return i
	return -1


## Quita de la mano la carta iid y la devuelve ({} si no está).
static func take_from_hand(player: Dictionary, iid: int) -> Dictionary:
	var i: int = hand_index(player, iid)
	if i < 0:
		return {}
	var hand: Array = player["hand"]
	var c: Dictionary = hand[i]
	hand.remove_at(i)
	return c


## Busca una carta en mesa (artefactos, maldiciones o evento activo) por iid.
## Devuelve {zone:"artifacts"|"curses"|"event", owner:pid, card:table_card} o {}.
static func find_in_play(state: Dictionary, iid: int) -> Dictionary:
	for p: Variant in state["players"]:
		var pd: Dictionary = p
		for zone: String in ["artifacts", "curses"]:
			for c: Variant in pd[zone]:
				var cd: Dictionary = c
				if int(cd["iid"]) == iid:
					return {"zone": zone, "owner": String(pd["id"]), "card": cd}
	var ev: Dictionary = state["active_event"]
	if not ev.is_empty() and int(ev["iid"]) == iid:
		return {"zone": "event", "owner": "", "card": ev}
	return {}
