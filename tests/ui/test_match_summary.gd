extends GutTest
## V2-26b (T26-B): MatchSummary.build. Casos C8-1 a C8-6, C8-12, C8-13.

const OH = preload("res://tests/engine/effects/offensive_helpers.gd")
const H = preload("res://tests/fixtures/engine_helpers.gd")

var s: Dictionary


func before_each() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	s = OH.make_state(4)


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func _p(pid: String) -> Dictionary:
	return Types.get_player(s, pid)


func _build(local: Array[String] = ["p1"]) -> Dictionary:
	return MatchSummary.build(s, local)


func _row(r: Dictionary, pid: String) -> Dictionary:
	for x: Variant in r["rows"]:
		if String((x as Dictionary)["pid"]) == pid:
			return x
	return {}


func _elim(pid: String, order: int, reason: String, by: String = "", card: String = "",
		cause: String = "") -> void:
	var p: Dictionary = _p(pid)
	p["eliminated"] = true
	p["hp"] = 0
	p["eliminated_reason"] = reason
	p["eliminated_order"] = order
	p["eliminated_by"] = by
	p["eliminated_card"] = card
	p["eliminated_cause"] = cause


## Partida P8-A de criterios-v02 (armada a mano). Ana p1 gana.
func _p8a() -> void:
	_elim("p4", 7, Types.ELIM_HP, "p2", Types.CARD_FIREBALL, Types.ELIM_CAUSE_DAMAGE)
	_elim("p3", 12, Types.ELIM_TOO_MUCH_MANA)
	_elim("p2", 16, Types.ELIM_HP, "p1", Types.CARD_LIGHTNING, Types.ELIM_CAUSE_DAMAGE)
	_p("p3")["potions"] = 11
	var t: Array = [5, 4, 3, 2]
	var po: Array = [4, 3, 11, 1]
	for i: int in 4:
		_p("p%d" % (i + 1))["turns_played"] = t[i]
		_p("p%d" % (i + 1))["potions"] = po[i]
	s["status"] = Types.STATUS_FINISHED
	s["winners"] = ["p1"]


func test_c8_1_victory_ranking() -> void:
	_p8a()
	var r: Dictionary = _build()
	assert_eq(r["title"], "¡Victoria!")
	var ids: Array = []
	for x: Variant in r["rows"]:
		ids.append((x as Dictionary)["pid"])
	assert_eq(ids, ["p1", "p2", "p3", "p4"])
	assert_eq(_row(r, "p1")["cause"], "Último en pie")
	assert_eq(_row(r, "p1")["blow"], "")
	assert_eq(_row(r, "p2")["cause"], "Se quedó sin vida")
	assert_eq(_row(r, "p2")["blow"], "Golpe final: P1 con Lightning")
	assert_eq(_row(r, "p3")["cause"], "Too Much Mana")
	assert_eq(_row(r, "p3")["blow"], "Bebió la poción n.º 11 (límite 10)")
	assert_eq(_row(r, "p4")["blow"], "Golpe final: P2 con Fireball")
	for i: int in 4:
		assert_eq((r["rows"] as Array)[i]["position"], i + 1)


func test_c8_2_turns_and_potions() -> void:
	_p8a()
	var r: Dictionary = _build()
	assert_eq([_row(r, "p1")["turns"], _row(r, "p1")["potions"]], [5, 4])
	assert_eq([_row(r, "p2")["turns"], _row(r, "p2")["potions"]], [4, 3])
	assert_eq([_row(r, "p3")["turns"], _row(r, "p3")["potions"]], [3, 11])
	assert_eq([_row(r, "p4")["turns"], _row(r, "p4")["potions"]], [2, 1])
	assert_eq(_row(r, "p3")["stats"], "Turnos: 3 · Pociones: 11 (límite 10)")
	assert_eq(_row(r, "p1")["stats"], "Turnos: 5 · Pociones: 4")


func test_c8_3_defeat_and_hot_seat() -> void:
	_p8a()
	# Gana Bruno: Ana cae antes.
	for pid: String in ["p1", "p2", "p3", "p4"]:
		var p: Dictionary = _p(pid)
		p["eliminated"] = false
		p["eliminated_order"] = 0
	_elim("p1", 20, Types.ELIM_HP, "p2", Types.CARD_FIREBALL, Types.ELIM_CAUSE_DAMAGE)
	s["winners"] = ["p2"]
	var r: Dictionary = _build(["p1"])
	assert_eq(r["title"], "Derrota")
	assert_eq((r["rows"] as Array)[0]["pid"], "p2")
	# Hot-seat: dos humanos locales.
	assert_eq(_build(["p1", "p2"])["title"], "Gana P2")
	assert_eq(_build(["p1", "p2"])["rows"][0]["pid"], "p2")


func test_c8_3_victory_not_for_other_winner() -> void:
	_p8a()
	assert_eq(_build(["p2"])["title"], "Derrota")


func test_c8_4_armageddon_tie_from_engine() -> void:
	for pid: String in ["p1", "p2", "p3", "p4"]:
		OH.set_hp(s, pid, 3)
	s["rev"] = 12
	assert_eq(OH.cast(s, "p1", Types.CARD_ARMAGEDDON, ["p1", "p2", "p3", "p4"])["error"], "")
	s["status"] = Types.STATUS_FINISHED
	s["winners"] = []
	var r: Dictionary = _build()
	assert_eq(r["title"], "Empate")
	assert_eq(r["subtitle"], "Todos los magos cayeron a la vez.")
	var ids: Array = []
	for x: Variant in r["rows"]:
		ids.append((x as Dictionary)["pid"])
		assert_eq((x as Dictionary)["position"], 1)
		assert_eq((x as Dictionary)["cause"], "Se quedó sin vida")
	assert_eq(ids, ["p1", "p2", "p3", "p4"], "orden de asiento")
	assert_eq(_row(r, "p1")["blow"], "Se eliminó a sí mismo con Armageddon")
	assert_eq(_row(r, "p3")["blow"], "Golpe final: P1 con Armageddon")


func test_c8_4_tie_none_left_text() -> void:
	_elim("p1", 3, Types.ELIM_HP)
	_elim("p2", 5, Types.ELIM_HP)
	_elim("p3", 2, Types.ELIM_HP)
	_elim("p4", 4, Types.ELIM_HP)
	s["winners"] = []
	var r: Dictionary = _build()
	assert_eq(r["subtitle"], "No queda ningún mago en pie.")
	assert_eq(_row(r, "p1")["blow"], "")
	assert_eq(_row(r, "p2")["position"], 1)
	assert_eq(_row(r, "p4")["position"], 2)


func test_c8_5_concede_from_engine() -> void:
	s["rev"] = 3
	var rr: Dictionary = Game.reduce(s, Types.make_action_concede("p1"))
	assert_eq(rr["error"], "")
	s = rr["state"]
	s["status"] = Types.STATUS_FINISHED
	s["winners"] = ["p2"]
	var r: Dictionary = _build()
	assert_eq(_row(r, "p1")["cause"], "Se rindió")
	assert_eq(_row(r, "p1")["blow"], "")
	assert_eq(_row(r, "p1")["text"], "P1 — Se rindió")


func test_c8_6_mana_shortfall_from_engine() -> void:
	OH.set_hp(s, "p2", 1)
	_p("p2")["mana"] = 0
	var events: Array = []
	Damage.lose_mana(s, "p2", 2, events, "p1", Types.CARD_MANA_IMPLOSION)
	var prs: Array = OH.prompts(s, "p2", Types.PROMPT_MANA_SHORTFALL)
	s["rev"] = 6
	var rr: Dictionary = Game.reduce(s, Types.make_action_decline("p2", int((prs[0] as Dictionary)["id"])))
	assert_eq(rr["error"], "")
	s = rr["state"]
	var r: Dictionary = _build()
	assert_eq(_row(r, "p2")["cause"], "Se quedó sin vida")
	assert_eq(_row(r, "p2")["blow"], "Por maná insuficiente")


func test_c8_6_visit_of_the_archmage_from_engine() -> void:
	OH.set_hp(s, "p2", 2)
	(s["pending"] as Array).append(Types.make_prompt(Types.next_seq(s), "p2",
		Types.PROMPT_DRINK_OR_SUFFER, {"hp": 2}, Types.CARD_VISIT_OF_THE_ARCHMAGE, true))
	var pr: int = int(((s["pending"] as Array)[0] as Dictionary)["id"])
	var rr: Dictionary = Game.reduce(s, Types.make_action_decline("p2", pr))
	assert_eq(rr["error"], "")
	s = rr["state"]
	assert_eq(_row(_build(), "p2")["blow"], "Por Visit of the Archmage")


func test_too_much_mana_from_engine_and_limit_disabled() -> void:
	_p("p2")["potions"] = int((s["config"] as Dictionary)["potion_limit"])
	var events: Array = []
	Damage.drink_potion(s, "p2", events)
	var r: Dictionary = _build()
	assert_eq(_row(r, "p2")["blow"], "Bebió la poción n.º 11 (límite 10)")
	(s["config"] as Dictionary)["potion_limit_enabled"] = false
	assert_eq(_row(_build(), "p2")["blow"], "Bebió la poción n.º 11")


func test_direct_hp_loss_has_no_blow_line() -> void:
	OH.kill(s, "p3")
	assert_eq(_row(_build(), "p3")["blow"], "")


func test_c8_12_no_internal_keys() -> void:
	_p8a()
	_elim("p4", 3, Types.ELIM_HP, "", Types.CARD_MANA_IMPLOSION, Types.ELIM_CAUSE_MANA_SHORTFALL)
	_p("p1")["name"] = "Ana"
	for r: Dictionary in [_build(), _tie_summary()]:
		var texts: Array = [r["title"], r["subtitle"]]
		for x: Variant in r["rows"]:
			var d: Dictionary = x
			texts.append_array([d["name"], d["cause"], d["blow"], d["stats"], d["text"]])
		for t: Variant in texts:
			assert_false(String(t).contains("_"), String(t))
			assert_false(String(t).contains("too_much_mana"), String(t))


func _tie_summary() -> Dictionary:
	for pid: String in ["p1", "p2", "p3", "p4"]:
		_elim(pid, 9, Types.ELIM_HP, "p1", Types.CARD_ARMAGEDDON, Types.ELIM_CAUSE_DAMAGE)
	s["winners"] = []
	return _build()


func test_c8_13_rows_cover_every_player_once() -> void:
	for n: int in [3, 4, 5, 6]:
		s = OH.make_state(n)
		for i: int in range(1, n):
			_elim("p%d" % (i + 1), i * 2 if i != 2 else 2, Types.ELIM_HP)
		_p("p4" if n > 3 else "p3")["eliminated_order"] = 2
		s["winners"] = ["p1"]
		var r: Dictionary = _build()
		var rows: Array = r["rows"]
		assert_eq(rows.size(), n)
		var seen: Dictionary = {}
		var prev: int = 0
		for i: int in rows.size():
			var d: Dictionary = rows[i]
			assert_false(seen.has(d["pid"]))
			seen[d["pid"]] = true
			assert_true(int(d["position"]) >= prev)
			assert_true(int(d["position"]) <= i + 1)
			prev = int(d["position"])
		assert_eq(rows[0]["position"], 1)


func test_empty_view_is_safe() -> void:
	var r: Dictionary = MatchSummary.build({}, [])
	assert_eq((r["rows"] as Array).size(), 0)
	assert_eq(r["title"], "Empate")


func test_new_game_view_without_log() -> void:
	var g: Dictionary = Game.new_game(H.make_players(3), {}, 3)
	g["log"] = []
	var r: Dictionary = MatchSummary.build(g, ["p1"])
	assert_eq((r["rows"] as Array).size(), 3)
