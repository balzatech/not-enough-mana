extends RefCounted
## Utilidades de los tests de efectos ofensivos (T6a). Usa el catálogo real.
##   const OH = preload("res://tests/engine/effects/offensive_helpers.gd")

const H = preload("res://tests/fixtures/engine_helpers.gd")


## Estado en juego con n jugadores p1..pn (10💖, `start_mana`💧, manos vacías), turno
## de p1 en fase main, sin eventos ni modificadores (no ejecuta efectos de T6c).
static func make_state(n: int = 4, start_mana: int = 10, seed_value: int = 7) -> Dictionary:
	var s: Dictionary = Types.make_state({}, seed_value)
	var c: Dictionary = s["config"]
	var ps: Array = []
	for i: int in n:
		var p: Dictionary = Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 30 + i, (i % 12) + 1)
		p["hp"] = int(c["start_hp"])
		p["mana"] = start_mana
		ps.append(p)
	s["players"] = ps
	var pool: Dictionary = s["pool"]
	pool["hp"] = int(pool["hp"]) - int(c["start_hp"]) * n
	pool["mana"] = int(pool["mana"]) - start_mana * n
	var deck: Array = Deck.build_instances(CardCatalog.all_defs(), c)
	s["deck"] = deck
	s["card_total"] = deck.size()
	Deck.shuffle_pile(s, "deck")
	s["status"] = Types.STATUS_PLAYING
	s["turn"] = Types.make_turn(1, "p1", Types.PHASE_MAIN)
	return s


## Resuelve directamente (sin ventana de reacción) un hechizo card_id lanzado
## por caster. Devuelve {error, events, iid}.
static func cast(s: Dictionary, caster: String, card_id: String, targets: Array,
		extra: Dictionary = {}) -> Dictionary:
	var card: Dictionary = H._take_any(s, card_id)
	assert(not card.is_empty(), "no queda %s" % card_id)
	var spell: Dictionary = Types.make_spell(card, caster, targets, extra)
	var events: Array = []
	var r: Dictionary = Game.resolve_spell(s, spell, events)
	return {"error": String(r["error"]), "events": events, "iid": int(card["iid"])}


## Resuelve un hechizo ya preparado (p. ej. un Lightning con cadena).
static func resolve(s: Dictionary, spell: Dictionary) -> Dictionary:
	var events: Array = []
	var r: Dictionary = Game.resolve_spell(s, spell, events)
	return {"error": String(r["error"]), "events": events}


## Error de Game.check_play al intentar jugar card_id sobre `targets` (la carta
## se pone en la mano de caster). Los errores de objetivo salen antes que los
## de pago, así que no hace falta pagar.
static func play_error(s: Dictionary, caster: String, card_id: String, targets: Array) -> String:
	var card: Dictionary = H._take_any(s, card_id)
	(H.hand(s, caster)).append(card)
	var a: Dictionary = Types.make_action_play_card(caster, int(card["iid"]), targets)
	return String(Game.check_play(s, caster, card, CardCatalog.get_def(card_id), a)["error"])


static func hp(s: Dictionary, pid: String) -> int:
	return int(Types.get_player(s, pid)["hp"])


static func mana(s: Dictionary, pid: String) -> int:
	return int(Types.get_player(s, pid)["mana"])


static func set_hp(s: Dictionary, pid: String, value: int) -> void:
	var p: Dictionary = Types.get_player(s, pid)
	var pool: Dictionary = s["pool"]
	pool["hp"] = int(pool["hp"]) + int(p["hp"]) - value
	p["hp"] = value


static func eliminated(s: Dictionary, pid: String) -> bool:
	return bool(Types.get_player(s, pid)["eliminated"])


## Elimina a pid (pierde toda su vida).
static func kill(s: Dictionary, pid: String) -> void:
	Damage.lose_hp(s, pid, hp(s, pid), [])


static func flags(s: Dictionary, pid: String) -> Dictionary:
	return Types.get_player(s, pid)["flags"]


## Modificador falso (como haría un artefacto/evento de T6c).
static func add_mod(s: Dictionary, id: String, stage: String, op: String, value: int,
		element: String = "", side: String = Types.SIDE_ANY, owner: String = "") -> void:
	Modifiers.add(s, Types.make_modifier(id, stage, op, value, owner, side, element,
		Types.EXPIRES_WHILE_IN_PLAY, "fake", -1))


## Prompts pendientes de pid de un kind.
static func prompts(s: Dictionary, pid: String, kind: String) -> Array:
	var out: Array = []
	for pr: Variant in s["pending"]:
		var d: Dictionary = pr
		if String(d["player"]) == pid and String(d["kind"]) == kind:
			out.append(d)
	return out


## Entradas de `events` de ese tipo (y, si what != "", con data.what == what).
static func events_of(events: Array, type: String, what: String = "") -> Array:
	var out: Array = []
	for e: Variant in events:
		var d: Dictionary = e
		if String(d["type"]) != type:
			continue
		if what != "" and String((d["data"] as Dictionary).get("what", "")) != what:
			continue
		out.append(d)
	return out
