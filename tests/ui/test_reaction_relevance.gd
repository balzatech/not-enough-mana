extends NemTest
## ReactionRelevance (V2-25a): "me afecta" y auto-pase. Casos R2-R10, R13, R17 del
## documento del Game Designer, con estados armados a mano (asientos p1..p4 = A..D;
## C = p3 es el humano local).

var _iid: int = 100


func before_each() -> void:
	super.before_each()
	CardCatalog.load_json()
	_iid = 100


func _state(n: int = 4, alive: Array = []) -> Dictionary:
	var s: Dictionary = Types.make_state({}, 1)
	var ps: Array = []
	for i: int in n:
		var p: Dictionary = Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 30 + i, (i % 12) + 1)
		p["hp"] = 10
		if not alive.is_empty() and not alive.has(p["id"]):
			p["eliminated"] = true
		ps.append(p)
	s["players"] = ps
	s["status"] = Types.STATUS_PLAYING
	s["turn"] = Types.make_turn(1, "p1", Types.PHASE_MAIN)
	return s


func _spell(card_id: String, caster: String, targets: Array, extra: Dictionary = {}, target_card: int = -1) -> Dictionary:
	_iid += 1
	return Types.make_spell({"iid": _iid, "card_id": card_id}, caster, targets, extra, false, target_card)


func _open(s: Dictionary, spell: Dictionary, awaiting: Array = ["p3"]) -> Dictionary:
	s["reaction"] = Types.make_reaction(spell, awaiting)
	return s


func _cast(card_id: String, caster: String, targets: Array, alive: Array = [], n: int = 4) -> Dictionary:
	return _open(_state(n, alive), _spell(card_id, caster, targets))


func _table(s: Dictionary, pid: String, zone: String, card: Dictionary) -> void:
	var arr: Array = Types.get_player(s, pid)[zone]
	arr.append(card)


func _push(s: Dictionary, resp: Dictionary) -> void:
	resp["is_response"] = true
	((s["reaction"] as Dictionary)["stack"] as Array).append(resp)


# --- R17: cobertura del catalogo ---------------------------------------------

func test_every_playable_card_has_rule() -> void:
	var n: int = 0
	for id: String in CardCatalog.all_defs():
		var d: Dictionary = CardCatalog.get_def(id)
		if not bool(d.get("playable", false)):
			continue
		n += 1
		assert_true(ReactionRelevance.has_rule(id), "%s sin regla" % id)
	assert_eq(n, 58, "58 cartas jugables")
	for id: String in Types.PLAYABLE_CARD_IDS:
		assert_true(ReactionRelevance.has_rule(id), id)


func test_rules_coherent_with_catalog() -> void:
	for id: String in CardCatalog.all_defs():
		var d: Dictionary = CardCatalog.get_def(id)
		if not bool(d.get("playable", false)):
			continue
		var r: String = ReactionRelevance.rule_of(id)
		var tg: String = String(d.get("target", ""))
		var ty: String = String(d.get("type", ""))
		if r == ReactionRelevance.R_ALL:
			assert_eq(tg, Types.TARGET_ALL, id)
		if tg == Types.TARGET_ALL:
			assert_eq(r, ReactionRelevance.R_ALL, id)
		if r == ReactionRelevance.R_ALL_OTHERS:
			assert_eq(tg, Types.TARGET_ALL_OTHERS, id)
		if tg == Types.TARGET_ALL_OTHERS:
			assert_eq(r, ReactionRelevance.R_ALL_OTHERS, id)
		if r in [ReactionRelevance.R_TARGETS, ReactionRelevance.R_AREA, ReactionRelevance.R_TARGETS_AND_CASTER]:
			assert_true(tg in [Types.TARGET_SINGLE, Types.TARGET_OTHER, Types.TARGET_TWO], "%s objetivo de jugador" % id)
		if r == ReactionRelevance.R_NONE:
			assert_false(ty in [Types.CARD_TYPE_OFFENSIVE, Types.CARD_TYPE_CURSE], "%s ofensiva/maldicion en none" % id)
		if ty == Types.CARD_TYPE_CURSE:
			assert_true(r in [ReactionRelevance.R_CONDITION, ReactionRelevance.R_EVERYONE], id)


func test_every_card_runs_without_error() -> void:
	for id: String in Types.PLAYABLE_CARD_IDS:
		var s: Dictionary = _cast(id, "p1", ["p2"])
		var rec: Array[String] = ReactionRelevance.receivers(s, (s["reaction"] as Dictionary)["spell"])
		assert_true(rec.size() <= 4, id)
		ReactionRelevance.affects(s, "p3")


# --- R2..R10 ------------------------------------------------------------------

func test_r2_direct_target() -> void:
	assert_true(ReactionRelevance.affects(_cast(Types.CARD_FIREBALL, "p1", ["p3"]), "p3"))
	assert_false(ReactionRelevance.affects(_cast(Types.CARD_FIREBALL, "p1", ["p2"]), "p3"))
	assert_true(ReactionRelevance.affects(_cast(Types.CARD_FIREBALL, "p3", ["p3"]), "p3"), "contra uno mismo")
	assert_true(ReactionRelevance.affects(_cast(Types.CARD_ELECTRIC_ARC, "p1", ["p2", "p3"]), "p3"))


func test_r3_area_neighbors() -> void:
	for id: String in [Types.CARD_METEOR_SHOWER, Types.CARD_BLIZZARD]:
		assert_true(ReactionRelevance.affects(_cast(id, "p1", ["p2"]), "p3"), "%s vecino" % id)
		assert_false(ReactionRelevance.affects(_cast(id, "p1", ["p1"]), "p3"), "%s no vecino" % id)
	var s: Dictionary = _cast(Types.CARD_METEOR_SHOWER, "p1", ["p1"], ["p1", "p3"])
	assert_true(ReactionRelevance.affects(s, "p3"), "con 2 vivos el otro es vecino")
	# vecinos vivos: con p2 eliminado, p1 y p3 son vecinos
	assert_true(ReactionRelevance.affects(_cast(Types.CARD_BLIZZARD, "p1", ["p4"], ["p1", "p3", "p4"]), "p3"))


func test_r4_all_and_all_others() -> void:
	assert_true(ReactionRelevance.affects(_cast(Types.CARD_ARMAGEDDON, "p1", []), "p3"))
	assert_true(ReactionRelevance.affects(_cast(Types.CARD_ELECTRIC_EXPLOSION, "p1", []), "p3"))
	var s: Dictionary = _cast(Types.CARD_ELECTRIC_EXPLOSION, "p3", [], ["p1", "p3"])
	assert_false(ReactionRelevance.affects(s, "p3"), "el lanzador no es receptor")
	assert_true(ReactionRelevance.affects(s, "p1"))
	assert_true(ReactionRelevance.affects(_cast(Types.CARD_ARMAGEDDON, "p3", []), "p3"), "Armageddon incluye al lanzador")


func test_ice_boomerang_includes_caster() -> void:
	var s: Dictionary = _cast(Types.CARD_ICE_BOOMERANG, "p3", ["p2"])
	assert_true(ReactionRelevance.affects(s, "p3"))
	assert_true(ReactionRelevance.affects(s, "p2"))
	assert_false(ReactionRelevance.affects(s, "p4"))


func test_r5_lightning_chain() -> void:
	var s: Dictionary = _cast(Types.CARD_LIGHTNING, "p1", ["p2"])
	assert_false(ReactionRelevance.affects(s, "p3"))
	_push(s, _spell(Types.CARD_LIGHTNING, "p2", ["p3"]))
	assert_true(ReactionRelevance.affects(s, "p3"), "destino de la cadena")
	var s2: Dictionary = _cast(Types.CARD_LIGHTNING, "p1", ["p2"])
	_push(s2, _spell(Types.CARD_LIGHTNING, "p2", ["p4"]))
	assert_false(ReactionRelevance.affects(s2, "p3"))
	assert_true(ReactionRelevance.affects(s2, "p4"))


func test_r6_mirror_shield() -> void:
	var s: Dictionary = _cast(Types.CARD_FIREBALL, "p1", ["p2"])
	_push(s, _spell(Types.CARD_MIRROR_SHIELD, "p2", ["p3"]))
	assert_true(ReactionRelevance.affects(s, "p3"))
	var s2: Dictionary = _cast(Types.CARD_FIREBALL, "p1", ["p2"])
	_push(s2, _spell(Types.CARD_MIRROR_SHIELD, "p2", ["p1"]))
	assert_false(ReactionRelevance.affects(s2, "p3"))


func test_r7_hand_cards() -> void:
	for id: String in [Types.CARD_BOOK_EXCHANGE, Types.CARD_MAGIC_HAND]:
		assert_true(ReactionRelevance.affects(_cast(id, "p1", ["p3"]), "p3"), id)
		assert_false(ReactionRelevance.affects(_cast(id, "p1", ["p2"]), "p3"), id)
		assert_false(ReactionRelevance.affects(_cast(id, "p3", ["p2"]), "p3"), "%s: el lanzador no" % id)


func test_r8_curses() -> void:
	var s: Dictionary = _state()  # edades p1=30 < p3=32
	_open(s, _spell(Types.CARD_CURSE_OF_THE_ELDER, "p1", []))
	assert_true(ReactionRelevance.affects(s, "p3"), "C mayor que A")
	_open(s, _spell(Types.CARD_CURSE_OF_THE_YOUNGER, "p1", []))
	assert_false(ReactionRelevance.affects(s, "p3"), "C no es mas joven")
	_open(s, _spell(Types.CARD_CURSE_OF_THE_ELDER, "p4", []))
	assert_false(ReactionRelevance.affects(s, "p3"), "C mas joven que D")
	_open(s, _spell(Types.CARD_CURSE_OF_RULES, "p1", []))
	assert_true(ReactionRelevance.affects(s, "p3"))
	# Vigour: vida >= la del lanzador, incluido el lanzador
	var pv: Dictionary = Types.get_player(s, "p3")
	pv["hp"] = 5
	_open(s, _spell(Types.CARD_CURSE_OF_VIGOUR, "p1", []))
	assert_false(ReactionRelevance.affects(s, "p3"))
	pv["hp"] = 10
	assert_true(ReactionRelevance.affects(s, "p3"))
	assert_true(ReactionRelevance.affects(s, "p1"), "el lanzador cumple")
	# Even/Odd: meses p1=1, p2=2, p3=3, p4=4
	_open(s, _spell(Types.CARD_CURSE_OF_EVEN, "p1", []))
	assert_false(ReactionRelevance.affects(s, "p3"))
	assert_true(ReactionRelevance.affects(s, "p2"))
	_open(s, _spell(Types.CARD_CURSE_OF_ODD, "p1", []))
	assert_true(ReactionRelevance.affects(s, "p3"))
	assert_true(ReactionRelevance.affects(s, "p1"))


func test_r9_heals_do_not_count() -> void:
	assert_false(ReactionRelevance.affects(_cast(Types.CARD_HEAL, "p1", ["p2"]), "p3"))
	assert_false(ReactionRelevance.affects(_cast(Types.CARD_HEAL, "p1", ["p3"]), "p3"))
	assert_false(ReactionRelevance.affects(_cast(Types.CARD_GREATER_HEAL, "p1", ["p3"]), "p3"))
	assert_false(ReactionRelevance.affects(_cast(Types.CARD_FORCE_FIELD, "p1", ["p3"]), "p3"))


func test_r10_annihilation() -> void:
	var s: Dictionary = _cast(Types.CARD_FIREBALL, "p2", ["p1"])
	_table(s, "p3", "artifacts", Types.make_table_card(900, Types.CARD_SPELLBOOK, "p3"))
	_table(s, "p4", "curses", Types.make_table_card(901, Types.CARD_CURSE_OF_RULES, "p4"))
	_push(s, _spell(Types.CARD_ANNIHILATION, "p1", [], {}, 900))
	assert_true(ReactionRelevance.affects(s, "p3"))
	var s2: Dictionary = _cast(Types.CARD_FIREBALL, "p2", ["p1"])
	_table(s2, "p3", "artifacts", Types.make_table_card(900, Types.CARD_SPELLBOOK, "p3"))
	_table(s2, "p4", "curses", Types.make_table_card(901, Types.CARD_CURSE_OF_RULES, "p4"))
	_push(s2, _spell(Types.CARD_ANNIHILATION, "p1", [], {}, 901))
	assert_false(ReactionRelevance.affects(s2, "p3"))
	assert_true(ReactionRelevance.affects(s2, "p4"))


func test_annihilation_against_stack_spell_and_unknown() -> void:
	var s: Dictionary = _open(_state(), _spell(Types.CARD_FIREBALL, "p3", ["p2"]))
	var main_iid: int = int(((((s["reaction"] as Dictionary)["spell"]) as Dictionary)["card"] as Dictionary)["iid"])
	_push(s, _spell(Types.CARD_ANNIHILATION, "p1", [], {}, main_iid))
	assert_true(ReactionRelevance.affects(s, "p3"), "cancela mi hechizo")
	var s2: Dictionary = _cast(Types.CARD_FIREBALL, "p2", ["p1"])
	_push(s2, _spell(Types.CARD_ANNIHILATION, "p1", [], {}, 12345))
	assert_true(ReactionRelevance.affects(s2, "p3"), "carta desconocida: duda")


func test_last_wish_reflects_to_caster() -> void:
	var s: Dictionary = _cast(Types.CARD_FIREBALL, "p3", ["p2"])
	var main_iid: int = int((((s["reaction"] as Dictionary)["spell"] as Dictionary)["card"] as Dictionary)["iid"])
	var lw: Dictionary = _spell(Types.CARD_LAST_WISH, "p2", [])
	(lw["data"] as Dictionary)["responds_to"] = main_iid
	_push(s, lw)
	assert_true(ReactionRelevance.affects(s, "p3"))
	assert_false(ReactionRelevance.affects(s, "p4"))


func test_cancelled_stack_entry_ignored() -> void:
	var s: Dictionary = _cast(Types.CARD_FIREBALL, "p1", ["p2"])
	var resp: Dictionary = _spell(Types.CARD_LIGHTNING, "p2", ["p3"])
	resp["cancelled"] = true
	_push(s, resp)
	assert_false(ReactionRelevance.affects(s, "p3"))


func test_defensive_responses_do_not_affect() -> void:
	var s: Dictionary = _cast(Types.CARD_FIREBALL, "p1", ["p2"])
	_push(s, _spell(Types.CARD_MAGIC_SHIELD, "p2", ["p3"]))
	assert_false(ReactionRelevance.affects(s, "p3"), "Magic Shield sobre mi: protege, no daña")


# --- R13 y auto-pase ----------------------------------------------------------

func test_r13_unknown_card_warns() -> void:
	var s: Dictionary = _cast("carta_inexistente", "p1", ["p2"])
	assert_true(ReactionRelevance.affects(s, "p3"))
	var local: Array[String] = ["p3"]
	assert_eq(ReactionRelevance.auto_pass_action(s, local, ReactionRelevance.MODE_AFFECTING), {})


func test_no_window_does_not_affect() -> void:
	assert_false(ReactionRelevance.affects(_state(), "p3"))


func test_auto_pass_action() -> void:
	var local: Array[String] = ["p3"]
	var s: Dictionary = _cast(Types.CARD_FIREBALL, "p1", ["p2"])
	assert_eq(ReactionRelevance.auto_pass_action(s, local, ReactionRelevance.MODE_AFFECTING), Types.make_action_pass_reaction("p3"))
	assert_eq(ReactionRelevance.auto_pass_action(s, local, ReactionRelevance.MODE_ALL), {}, "R11: modo todos")
	assert_eq(ReactionRelevance.auto_pass_action(s, ["p4"] as Array[String], ReactionRelevance.MODE_AFFECTING), {}, "no es local / no le toca")
	var s2: Dictionary = _cast(Types.CARD_FIREBALL, "p1", ["p3"])
	assert_eq(ReactionRelevance.auto_pass_action(s2, local, ReactionRelevance.MODE_AFFECTING), {}, "R2")


func test_auto_pass_never_with_pending_prompt() -> void:
	var local: Array[String] = ["p3"]
	var s: Dictionary = _cast(Types.CARD_FIREBALL, "p1", ["p2"])
	s["pending"] = [{"type": Types.PROMPT_MANA_SHORTFALL, "player": "p3"}]
	assert_eq(ReactionRelevance.auto_pass_action(s, local, ReactionRelevance.MODE_AFFECTING), {}, "R14")
