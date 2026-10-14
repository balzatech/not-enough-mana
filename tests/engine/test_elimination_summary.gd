extends GutTest
## V2-26a (T26-A): el motor rellena los campos del resumen de fin por jugador
## (turns_played, eliminated_order/turn/by/card/cause). Casos C8-1, C8-2, C8-4 a C8-8.

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


# --- C8-1 / C8-2 -----------------------------------------------------------------

func test_c8_1_fireball_final_blow() -> void:
	OH.set_hp(s, "p3", 2)
	s["rev"] = 4
	(s["turn"] as Dictionary)["number"] = 7
	var r: Dictionary = OH.cast(s, "p2", Types.CARD_FIREBALL, ["p3"])
	assert_eq(r["error"], "")
	var p: Dictionary = _p("p3")
	assert_true(bool(p["eliminated"]))
	assert_eq(p["eliminated_reason"], Types.ELIM_HP)
	assert_eq(p["eliminated_by"], "p2")
	assert_eq(p["eliminated_card"], Types.CARD_FIREBALL)
	assert_eq(p["eliminated_cause"], Types.ELIM_CAUSE_DAMAGE)
	assert_eq(p["eliminated_order"], 5, "rev + 1")
	assert_eq(p["eliminated_turn"], 7)


func test_c8_1_lightning_final_blow_and_order_grows() -> void:
	OH.set_hp(s, "p2", 1)
	OH.set_hp(s, "p3", 1)
	s["rev"] = 1
	OH.cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	s["rev"] = 2
	OH.cast(s, "p1", Types.CARD_FIREBALL, ["p3"])
	assert_eq(_p("p2")["eliminated_by"], "p1")
	assert_eq(_p("p2")["eliminated_card"], Types.CARD_LIGHTNING)
	assert_eq(_p("p2")["eliminated_order"], 2)
	assert_eq(_p("p3")["eliminated_order"], 3)
	assert_eq(_p("p1")["eliminated_order"], 0, "vivo")
	assert_eq(_p("p1")["eliminated_cause"], "")


func test_c8_2_too_much_mana_has_no_blow() -> void:
	var p: Dictionary = _p("p2")
	p["potions"] = int((s["config"] as Dictionary)["potion_limit"])
	s["rev"] = 9
	var events: Array = []
	var res: Dictionary = Damage.drink_potion(s, "p2", events)
	assert_true(bool(res["eliminated"]))
	assert_eq(p["eliminated_reason"], Types.ELIM_TOO_MUCH_MANA)
	assert_eq(p["eliminated_by"], "")
	assert_eq(p["eliminated_card"], "")
	assert_eq(p["eliminated_cause"], "")
	assert_eq(p["eliminated_order"], 10)
	assert_eq(p["eliminated_turn"], 1)


# --- C8-4 ------------------------------------------------------------------------

func test_c8_4_armageddon_simultaneous_same_order() -> void:
	for pid: String in ["p1", "p2", "p3", "p4"]:
		OH.set_hp(s, pid, 3)
	s["rev"] = 12
	assert_eq(OH.cast(s, "p1", Types.CARD_ARMAGEDDON, ["p1", "p2", "p3", "p4"])["error"], "")
	for pid: String in ["p1", "p2", "p3", "p4"]:
		var p: Dictionary = _p(pid)
		assert_eq(p["eliminated_order"], 13, pid)
		assert_eq(p["eliminated_by"], "p1", pid)
		assert_eq(p["eliminated_card"], Types.CARD_ARMAGEDDON, pid)
		assert_eq(p["eliminated_cause"], Types.ELIM_CAUSE_DAMAGE, pid)


# --- C8-5 ------------------------------------------------------------------------

func test_c8_5_concede() -> void:
	s["rev"] = 3
	var r: Dictionary = Game.reduce(s, Types.make_action_concede("p2"))
	assert_eq(r["error"], "")
	var p: Dictionary = Types.get_player(r["state"], "p2")
	assert_eq(p["eliminated_reason"], Types.ELIM_CONCEDE)
	assert_eq(p["eliminated_order"], 4)
	assert_eq(p["eliminated_by"], "")
	assert_eq(p["eliminated_card"], "")
	assert_eq(p["eliminated_cause"], "")


# --- C8-6 ------------------------------------------------------------------------

func test_c8_6_mana_shortfall_decline() -> void:
	OH.set_hp(s, "p2", 1)
	_p("p2")["mana"] = 0
	var events: Array = []
	Damage.lose_mana(s, "p2", 2, events, "p1", Types.CARD_MANA_IMPLOSION)
	var prs: Array = OH.prompts(s, "p2", Types.PROMPT_MANA_SHORTFALL)
	assert_eq(prs.size(), 1)
	s["rev"] = 6
	var r: Dictionary = Game.reduce(s, Types.make_action_decline("p2", int((prs[0] as Dictionary)["id"])))
	assert_eq(r["error"], "")
	var p: Dictionary = Types.get_player(r["state"], "p2")
	assert_true(bool(p["eliminated"]))
	assert_eq(p["eliminated_reason"], Types.ELIM_HP)
	assert_eq(p["eliminated_cause"], Types.ELIM_CAUSE_MANA_SHORTFALL)
	assert_eq(p["eliminated_by"], "")
	assert_eq(p["eliminated_card"], Types.CARD_MANA_IMPLOSION)
	assert_eq(p["eliminated_order"], 7)


func test_c8_6_visit_of_the_archmage_decline() -> void:
	OH.set_hp(s, "p2", 2)
	(s["pending"] as Array).append(Types.make_prompt(Types.next_seq(s), "p2",
		Types.PROMPT_DRINK_OR_SUFFER, {"hp": 2}, Types.CARD_VISIT_OF_THE_ARCHMAGE, true))
	var pid_prompt: int = int(((s["pending"] as Array)[0] as Dictionary)["id"])
	var r: Dictionary = Game.reduce(s, Types.make_action_decline("p2", pid_prompt))
	assert_eq(r["error"], "")
	var p: Dictionary = Types.get_player(r["state"], "p2")
	assert_true(bool(p["eliminated"]))
	assert_eq(p["eliminated_by"], "")
	assert_eq(p["eliminated_card"], Types.CARD_VISIT_OF_THE_ARCHMAGE)
	assert_eq(p["eliminated_cause"], Types.ELIM_CAUSE_DAMAGE)


func test_direct_hp_loss_cause() -> void:
	OH.kill(s, "p3")
	assert_eq(_p("p3")["eliminated_cause"], Types.ELIM_CAUSE_HP_LOSS)


# --- C8-7 ------------------------------------------------------------------------

func test_c8_7_turns_played_counts_frozen_turn() -> void:
	assert_eq(OH.cast(s, "p1", Types.CARD_FREEZE, ["p2"])["error"], "")
	var events: Array = []
	Game._end_turn(s, "p1", events)
	assert_eq((s["turn"] as Dictionary)["current"], "p3")
	assert_eq(_p("p2")["turns_played"], 1, "el turno perdido por Freeze cuenta")
	assert_eq(_p("p3")["turns_played"], 1)
	assert_eq(_p("p1")["turns_played"], 0)


func test_turns_played_in_new_game() -> void:
	var g: Dictionary = Game.new_game(H.make_players(3), {}, 3)
	var total: int = 0
	for p: Variant in g["players"]:
		total += int((p as Dictionary)["turns_played"])
	assert_eq(total, 1, "el primer turno ya cuenta")
	assert_eq(Types.get_player(g, String((g["turn"] as Dictionary)["current"]))["turns_played"], 1)


# --- C8-8 ------------------------------------------------------------------------

func _run(log_limit: int) -> Array:
	var g: Dictionary = Game.new_game(H.make_players(4), {"log_limit": log_limit}, 11)
	var errs: Array = []
	for step: int in 400:
		if String(g["status"]) != Types.STATUS_PLAYING:
			break
		var acts: Array = []
		for pid: String in Types.alive_ids(g):
			for a: Variant in Game.legal_actions(g, pid):
				if String((a as Dictionary)["type"]) != Types.ACTION_CONCEDE:
					acts.append(a)
		if acts.is_empty():
			break
		var r: Dictionary = Game.reduce(g, acts[(step * 7) % acts.size()] as Dictionary)
		if String(r["error"]) != "":
			continue
		g = r["state"]
		errs.append_array(Types.validate_state(g))
	var out: Array = [errs]
	for p: Variant in g["players"]:
		var pd: Dictionary = p
		out.append([pd["turns_played"], pd["eliminated_order"], pd["eliminated_turn"],
			pd["eliminated_by"], pd["eliminated_card"], pd["eliminated_cause"], pd["eliminated_reason"]])
	return out


func test_c8_8_fields_independent_of_log_limit() -> void:
	var a: Array = _run(20)
	var b: Array = _run(100000)
	assert_eq((a[0] as Array).size(), 0, "validate_state vacío")
	assert_eq(a, b)


func test_normalize_state_fills_missing_keys() -> void:
	var raw: Dictionary = Game.new_game(H.make_players(3), {}, 5).duplicate(true)
	for p: Variant in raw["players"]:
		for k: String in ["turns_played", "eliminated_order", "eliminated_turn",
				"eliminated_by", "eliminated_card", "eliminated_cause"]:
			(p as Dictionary).erase(k)
	var n: Dictionary = Types.normalize_state(raw)
	for p: Variant in n["players"]:
		assert_eq((p as Dictionary)["eliminated_order"], 0)
		assert_eq((p as Dictionary)["eliminated_by"], "")
	assert_eq(Types.validate_state(n).size(), 0)
