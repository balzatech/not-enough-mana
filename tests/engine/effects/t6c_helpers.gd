extends RefCounted
## Utilidades de los tests de T6c (soporte, maldiciones, artefactos, eventos).
## Usan el catálogo real (data/cards.json) y el registro real.
##   const X = preload("res://tests/engine/effects/t6c_helpers.gd")

const H = preload("res://tests/fixtures/engine_helpers.gd")


## Partida de 3 jugadores con catálogo real: p1 40 años (mes 1), p2 30 (mes 2),
## p3 20 (mes 3). Turno de p1 en fase principal, sin evento ni prompts.
static func new_state(seed_value: int = 7) -> Dictionary:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var s: Dictionary = H.game(3, {}, seed_value, [40, 30, 20])
	H.force_turn(s, "p1")
	s["pending"] = []
	return s


## Añade a la mano de pid una carta card_id (sacada de cualquier zona). Devuelve su iid.
static func give(s: Dictionary, pid: String, card_id: String) -> int:
	var c: Dictionary = H._take_any(s, card_id)
	assert(not c.is_empty(), "no queda %s" % card_id)
	H.hand(s, pid).append(c)
	return int(c["iid"])


## Pone un artefacto en la mesa de pid jugándolo de verdad (paga su coste con
## maná regalado y cartas que cumplan el requisito). Devuelve el estado nuevo.
static func equip(t: GutTest, s: Dictionary, pid: String, card_id: String) -> Dictionary:
	H.force_turn(s, pid)
	var iid: int = give(s, pid, card_id)
	var pay: Array = pay_for(s, pid, card_id)
	var def: Dictionary = CardCatalog.get_def(card_id)
	var p: Dictionary = H.player(s, pid)
	var before: int = int(p["mana"])
	p["mana"] = before + Damage.card_cost(s, pid, def)
	var ns: Dictionary = play(t, s, Types.make_action_play_card(pid, iid, [], pay))
	H.player(ns, pid)["mana"] = before
	return ns


## Da a pid cartas que cubran los requisitos de coste en cartas de card_id.
static func pay_for(s: Dictionary, pid: String, card_id: String) -> Array:
	var out: Array = []
	var def: Dictionary = CardCatalog.get_def(card_id)
	for r: Variant in (def["cost"] as Dictionary)["cards"]:
		var rd: Dictionary = r
		for _i: int in int(rd["count"]):
			out.append(give(s, pid, card_for_req(rd)))
	return out


static func card_for_req(req: Dictionary) -> String:
	match String(req["by"]):
		Types.REQ_BY_ELEMENT:
			match String(req["value"]):
				Types.ELEMENT_FIRE:
					return Types.CARD_FIRE_ARROW
				Types.ELEMENT_ICE:
					return Types.CARD_ICE_BOLT
				_:
					return Types.CARD_LIGHTNING
		Types.REQ_BY_TYPE:
			match String(req["value"]):
				Types.CARD_TYPE_DEFENSIVE:
					return Types.CARD_MAGIC_SHIELD
				Types.CARD_TYPE_SUPPORT:
					return Types.CARD_HEAL
				Types.CARD_TYPE_OFFENSIVE:
					return Types.CARD_FIREBALL
		Types.REQ_BY_CARD:
			return String(req["value"])
	return Types.CARD_HEAL


## Reduce (fallando el test si hay error) y cierra la ventana de reacción si
## se abre (todos pasan).
static func play(t: GutTest, s: Dictionary, a: Dictionary) -> Dictionary:
	var ns: Dictionary = H.ok(t, s, a)
	return pass_all(t, ns)


static func pass_all(t: GutTest, s: Dictionary) -> Dictionary:
	var ns: Dictionary = s
	for _guard: int in 20:
		var re: Dictionary = ns["reaction"]
		if re.is_empty():
			return ns
		var awaiting: Array = re["awaiting"]
		if awaiting.is_empty():
			return ns
		ns = H.ok(t, ns, Types.make_action_pass_reaction(String(awaiting[0])))
	return ns


## Juega card_id desde la mano de pid (la añade, paga cartas y maná).
static func cast(t: GutTest, s: Dictionary, pid: String, card_id: String, targets: Array = [],
		extra: Dictionary = {}) -> Dictionary:
	H.force_turn(s, pid)
	var iid: int = give(s, pid, card_id)
	var pay: Array = pay_for(s, pid, card_id)
	var def: Dictionary = CardCatalog.get_def(card_id)
	var p: Dictionary = H.player(s, pid)
	p["mana"] = int(p["mana"]) + Damage.card_cost(s, pid, def)
	return play(t, s, Types.make_action_play_card(pid, iid, targets, pay, extra))


## Activa un evento como si se hubiera robado.
static func event(s: Dictionary, card_id: String, drawer: String = "p1") -> Array:
	var events: Array = []
	Game.activate_event(s, H._take_any(s, card_id), drawer, events)
	return events


## Daño de hechizo elemental de `source` a `target`.
static func spell_damage(s: Dictionary, source: String, target: String, amount: int, element: String,
		card_id: String = Types.CARD_FIREBALL) -> Dictionary:
	var ev: Dictionary = Types.make_mod_event(Damage.KIND_DAMAGE, amount, source, target, element, card_id, 9999, true)
	return Damage.resolve(s, ev, [])


static func prompts_of(s: Dictionary, pid: String, kind: String) -> Array:
	var out: Array = []
	for pr: Variant in s["pending"]:
		var prd: Dictionary = pr
		if String(prd["player"]) == pid and String(prd["kind"]) == kind:
			out.append(prd)
	return out


static func hp(s: Dictionary, pid: String) -> int:
	return int(H.player(s, pid)["hp"])


static func mana(s: Dictionary, pid: String) -> int:
	return int(H.player(s, pid)["mana"])


static func has_mod_from(s: Dictionary, card_id: String) -> bool:
	for m: Variant in s["modifiers"]:
		if String((m as Dictionary)["source_card"]) == card_id:
			return true
	return false


static func valid(t: GutTest, s: Dictionary) -> void:
	var errs: Array[String] = Types.validate_state(s)
	t.assert_true(errs.is_empty(), "estado válido: %s" % str(errs))
