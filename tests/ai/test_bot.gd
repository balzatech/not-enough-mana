extends GutTest
## T9: heurísticas del bot (una por test). Usa el catálogo real y los efectos
## falsos de los helpers del motor (los reales se registran en T6a-c).

const H = preload("res://tests/fixtures/engine_helpers.gd")


func before_each() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()
	H.register_fake_effects()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


## Partida de n magos con p1 en turno (fase main), mano y maná dados.
func _setup(n: int, hand: Array, mana: int) -> Dictionary:
	var s: Dictionary = H.game(n, {}, 5)
	H.force_turn(s, "p1")
	H.set_hand(s, "p1", hand)
	H.set_mana(s, "p1", mana)
	return s


func _act(s: Dictionary, pid: String = "p1", randomness: int = 0) -> Dictionary:
	var r: Dictionary = Bot.choose_action(s, pid, 123, randomness)
	return r["action"]


func _iid(s: Dictionary, pid: String, card_id: String) -> int:
	for c: Variant in H.hand(s, pid):
		if (c as Dictionary)["card_id"] == card_id:
			return int((c as Dictionary)["iid"])
	return -1


func _set_hp(s: Dictionary, pid: String, hp: int) -> void:
	H.player(s, pid)["hp"] = hp


# --- API general -------------------------------------------------------------

func test_returns_legal_action_and_not_state_mutation() -> void:
	var s: Dictionary = H.game(4, {}, 9)
	var before: String = JSON.stringify(s)
	var a: Dictionary = _act(s, (s["turn"] as Dictionary)["current"])
	assert_eq(JSON.stringify(s), before, "el bot no muta el estado")
	var legal: Array = Game.legal_actions(s, (s["turn"] as Dictionary)["current"])
	var found: bool = false
	for x: Variant in legal:
		if JSON.stringify(x) == JSON.stringify(a):
			found = true
	assert_true(found, "la acción está entre las legales")


func test_no_decision_returns_empty_action() -> void:
	var s: Dictionary = H.game(3, {}, 9)
	var other: String = "p2" if (s["turn"] as Dictionary)["current"] != "p2" else "p3"
	assert_false(Bot.has_decision(s, other))
	assert_true((_act(s, other) as Dictionary).is_empty())


func test_deterministic_and_rng_untouched_at_zero() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_FIRE_ARROW, Types.CARD_LIGHTNING], 5)
	var r1: Dictionary = Bot.choose_action(s, "p1", 777, 0)
	var r2: Dictionary = Bot.choose_action(s, "p1", 777, 0)
	assert_eq(JSON.stringify(r1), JSON.stringify(r2))
	assert_eq(int(r1["rng_state"]), 777)


func test_randomness_consumes_rng_and_stays_legal() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_FIRE_ARROW, Types.CARD_LIGHTNING], 5)
	var r: Dictionary = Bot.choose_action(s, "p1", 777, 60)
	assert_ne(int(r["rng_state"]), 777)
	assert_eq(String(Game.reduce(s, r["action"])["error"]), "")


func test_does_not_use_hidden_information() -> void:
	# Cambiar manos ajenas y mazo no altera la decisión de p1.
	for seed_v: int in [3, 4, 5, 6]:
		var s: Dictionary = H.game(4, {}, seed_v)
		var cur: String = (s["turn"] as Dictionary)["current"]
		var base: String = JSON.stringify(Bot.choose_action(s, cur, 5, 0))
		var s2: Dictionary = s.duplicate(true)
		for p: Variant in s2["players"]:
			var pd: Dictionary = p
			if pd["id"] != cur:
				(pd["hand"] as Array).reverse()
				if (pd["hand"] as Array).size() > 1:
					(pd["hand"] as Array).pop_back()
		(s2["deck"] as Array).reverse()
		s2["rng_state"] = 99
		assert_eq(JSON.stringify(Bot.choose_action(s2, cur, 5, 0)), base, "semilla %d" % seed_v)


# --- Objetivos y jugadas que matan -------------------------------------------

func test_prefers_kill_over_other_play() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_FIRE_ARROW, Types.CARD_ICE_BOOMERANG], 6)
	_set_hp(s, "p2", 3)
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_PLAY_CARD)
	assert_eq(int(a["card"]), _iid(s, "p1", Types.CARD_ICE_BOOMERANG))
	assert_eq(a["targets"], ["p2"])


func test_targets_weakest_rival() -> void:
	var s: Dictionary = _setup(4, [Types.CARD_FIRE_ARROW], 5)
	_set_hp(s, "p2", 9)
	_set_hp(s, "p3", 4)
	_set_hp(s, "p4", 8)
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_PLAY_CARD)
	assert_eq(a["targets"], ["p3"])


func test_never_targets_itself_with_offensive() -> void:
	for n: int in [2, 3, 5]:
		var s: Dictionary = _setup(n, [Types.CARD_LIGHTNING], 5)
		_set_hp(s, "p1", 1)
		var a: Dictionary = _act(s)
		assert_eq(a["type"], Types.ACTION_PLAY_CARD)
		assert_false((a["targets"] as Array).has("p1"))


func test_skips_target_with_force_field() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_FIRE_ARROW], 5)
	_set_hp(s, "p2", 2)
	(H.player(s, "p2")["flags"] as Dictionary)["force_field"] = "p3"
	var a: Dictionary = _act(s)
	assert_eq(a["targets"], ["p3"])


func test_avoids_suicidal_armageddon() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_ARMAGEDDON, Types.CARD_FIREBALL, Types.CARD_ICE_BOLT, Types.CARD_LIGHTNING], 9)
	_set_hp(s, "p1", 3)
	var a: Dictionary = _act(s)
	if a["type"] == Types.ACTION_PLAY_CARD:
		assert_ne(int(a["card"]), _iid(s, "p1", Types.CARD_ARMAGEDDON))


# --- Curación -----------------------------------------------------------------

func test_heals_self_when_low_hp() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_HEAL, Types.CARD_FIRE_ARROW], 5)
	_set_hp(s, "p1", 2)
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_PLAY_CARD)
	assert_eq(int(a["card"]), _iid(s, "p1", Types.CARD_HEAL))
	assert_eq(a["targets"], ["p1"])


func test_does_not_heal_at_full_hp() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_HEAL], 2)
	var a: Dictionary = _act(s)
	assert_ne(a["type"], Types.ACTION_PLAY_CARD)


# --- Pociones -----------------------------------------------------------------

func test_drinks_potion_when_short_of_mana_for_best_play() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_LIGHTNING], 0)
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_DRINK_POTION)


func test_does_not_drink_when_potion_would_not_help() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_LIGHTNING], 0)
	# Sin margen para acumular maná y la poción (1) no llega al coste de Lightning (2).
	H.player(s, "p1")["potions"] = int((s["config"] as Dictionary)["potion_limit"]) - 2
	s["config"]["potion_mana"] = 1
	var a: Dictionary = _act(s)
	assert_ne(a["type"], Types.ACTION_DRINK_POTION)


func test_never_drinks_past_too_much_mana_limit() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_LIGHTNING], 0)
	var limit: int = int((s["config"] as Dictionary)["potion_limit"])
	for potions: int in [limit]:
		H.player(s, "p1")["potions"] = potions
		var a: Dictionary = _act(s)
		assert_ne(a["type"], Types.ACTION_DRINK_POTION, "potions=%d" % potions)


func test_potion_prompts_decline_when_unsafe() -> void:
	var s: Dictionary = _setup(3, [], 0)
	var limit: int = int((s["config"] as Dictionary)["potion_limit"])
	(s["pending"] as Array).append(Types.make_prompt(1, "p1", Types.PROMPT_DRINK_OR_SUFFER, {"hp": 2}, Types.CARD_VISIT_OF_THE_ARCHMAGE))
	s["seq"] = 1
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_DRINK_POTION, "con margen bebe")
	assert_eq(int(a["prompt_id"]), 1)
	H.player(s, "p1")["potions"] = limit
	a = _act(s)
	assert_eq(a["type"], Types.ACTION_DECLINE, "sin margen rechaza")


func test_mana_shortfall_prompt() -> void:
	var s: Dictionary = _setup(3, [], 0)
	(s["pending"] as Array).append(Types.make_prompt(1, "p1", Types.PROMPT_MANA_SHORTFALL, {"missing": 2}, "x"))
	s["seq"] = 1
	assert_eq(_act(s)["type"], Types.ACTION_DRINK_POTION)
	H.player(s, "p1")["potions"] = int((s["config"] as Dictionary)["potion_limit"])
	assert_eq(_act(s)["type"], Types.ACTION_DECLINE)


# --- Descartar, intercambiar y terminar --------------------------------------

func test_ends_turn_with_nothing_useful() -> void:
	var s: Dictionary = _setup(3, [], 6)
	assert_eq(_act(s)["type"], Types.ACTION_END_TURN)


func test_does_not_waste_potions_when_idle() -> void:
	var s: Dictionary = _setup(3, [], 0)
	assert_eq(_act(s)["type"], Types.ACTION_END_TURN)


func test_discards_useless_card() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_CURSE_OF_RULES], 0)
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_DISCARD)
	assert_eq(a["cards"], [_iid(s, "p1", Types.CARD_CURSE_OF_RULES)])


func test_exchanges_only_with_spare_mana() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_HEAL], 1)
	assert_ne(_act(s)["type"], Types.ACTION_EXCHANGE, "poco maná: no intercambia")
	H.set_mana(s, "p1", 9)
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_EXCHANGE, "maná de sobra: intercambia")


func test_discards_least_valuable_on_discard_prompt() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_FIREBALL, Types.CARD_CURSE_OF_RULES, Types.CARD_LIGHTNING], 0)
	(s["pending"] as Array).append(Types.make_prompt(1, "p1", Types.PROMPT_DISCARD, {"count": 1}, Types.CARD_ICE_BOLT))
	s["seq"] = 1
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_CHOOSE_CARDS)
	assert_eq(a["cards"], [_iid(s, "p1", Types.CARD_CURSE_OF_RULES)])


func test_choose_targets_prompt_picks_weakest_rival() -> void:
	var s: Dictionary = _setup(4, [], 0)
	_set_hp(s, "p3", 3)
	(s["pending"] as Array).append(Types.make_prompt(1, "p1", Types.PROMPT_CHOOSE_TARGETS,
		{"count": 1, "allowed": ["p1", "p2", "p3", "p4"]}, Types.CARD_LIGHTNING))
	s["seq"] = 1
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_CHOOSE_TARGETS)
	assert_eq(a["targets"], ["p3"])


# --- Anti-bucle ---------------------------------------------------------------

func test_action_cap_forces_end_turn() -> void:
	var s: Dictionary = _setup(3, [Types.CARD_FIRE_ARROW, Types.CARD_LIGHTNING], 9)
	var t: int = int((s["turn"] as Dictionary)["number"])
	for i: int in Bot.MAX_ACTIONS_PER_TURN:
		(s["log"] as Array).append(Types.make_log_entry(Types.LOG_CARD_PLAYED, t, "p1", {}))
	assert_eq(_act(s)["type"], Types.ACTION_END_TURN)


# --- Prompts que el motor aún no enumera (acciones legales fabricadas) --------

func _view_with_prompt(s: Dictionary, pid: String, pr: Dictionary) -> Dictionary:
	(s["pending"] as Array).append(pr)
	s["seq"] = int(pr["id"])
	return Types.view_for(s, pid)


func test_magic_cap_used_only_for_big_losses() -> void:
	var s: Dictionary = _setup(3, [], 4)
	var big: Dictionary = Types.make_prompt(1, "p1", Types.PROMPT_USE_MAGIC_CAP,
		{"loss": {"kind": "damage", "amount": 3}}, Types.CARD_MAGIC_CAP, true)
	var legal: Array = [Types.make_action_use_artifact("p1", 50, [], [], {}, 1), Types.make_action_decline("p1", 1)]
	var v: Dictionary = _view_with_prompt(s, "p1", big)
	assert_eq(Bot.choose_among(v, "p1", legal, 1)["action"]["type"], Types.ACTION_USE_ARTIFACT)
	var small: Dictionary = Types.make_prompt(1, "p1", Types.PROMPT_USE_MAGIC_CAP,
		{"loss": {"kind": "damage", "amount": 1}}, Types.CARD_MAGIC_CAP, true)
	var s2: Dictionary = _setup(3, [], 4)
	var v2: Dictionary = _view_with_prompt(s2, "p1", small)
	assert_eq(Bot.choose_among(v2, "p1", legal, 1)["action"]["type"], Types.ACTION_DECLINE)


func test_mana_focus_converts_lethal_damage_to_mana() -> void:
	var s: Dictionary = _setup(3, [], 5)
	_set_hp(s, "p1", 2)
	var pr: Dictionary = Types.make_prompt(1, "p1", Types.PROMPT_MANA_FOCUS, {"damage": 2}, Types.CARD_MANA_FOCUS, true)
	var legal: Array = [Types.make_action_use_event("p1", {"mana": 0}, 1), Types.make_action_use_event("p1", {"mana": 1}, 1),
		Types.make_action_use_event("p1", {"mana": 2}, 1), Types.make_action_decline("p1", 1)]
	var v: Dictionary = _view_with_prompt(s, "p1", pr)
	var a: Dictionary = Bot.choose_among(v, "p1", legal, 1)["action"]
	assert_eq(a["type"], Types.ACTION_USE_EVENT)
	assert_eq(int((a["extra"] as Dictionary)["mana"]), 2)
	# Con vida de sobra y poco maná: rechaza.
	var s2: Dictionary = _setup(3, [], 1)
	var pr2: Dictionary = Types.make_prompt(1, "p1", Types.PROMPT_MANA_FOCUS, {"damage": 1}, Types.CARD_MANA_FOCUS, true)
	var v2: Dictionary = _view_with_prompt(s2, "p1", pr2)
	assert_eq(Bot.choose_among(v2, "p1", legal, 1)["action"]["type"], Types.ACTION_DECLINE)


# --- Ventana de reacción (acciones REACT fabricadas: reactions.gd es de T6b) --

func _reaction_view(hp: int, mana: int, hand: Array, spell_card: String, targets: Array) -> Array:
	var s: Dictionary = _setup(3, [], 0)
	H.set_hand(s, "p2", hand)
	H.set_mana(s, "p2", mana)
	_set_hp(s, "p2", hp)
	var spell: Dictionary = Types.make_spell({"iid": 9999, "card_id": spell_card}, "p1", targets)
	s["reaction"] = Types.make_reaction(spell, ["p2"])
	return [s, Types.view_for(s, "p2")]


func _react(s: Dictionary, card_id: String, targets: Array, target_card: int = -1) -> Dictionary:
	return Types.make_action_react("p2", _iid(s, "p2", card_id), targets, [], {}, target_card)


func test_reacts_with_cheapest_defense_when_lethal() -> void:
	var r: Array = _reaction_view(2, 5, [Types.CARD_FROZEN_BUNNY, Types.CARD_MAGIC_SHIELD], Types.CARD_FIREBALL, ["p2"])
	var s: Dictionary = r[0]
	var legal: Array = [Types.make_action_pass_reaction("p2"), _react(s, Types.CARD_MAGIC_SHIELD, ["p2"]),
		_react(s, Types.CARD_FROZEN_BUNNY, ["p2"])]
	var a: Dictionary = Bot.choose_among(r[1], "p2", legal, 1)["action"]
	assert_eq(a["type"], Types.ACTION_REACT)
	assert_eq(int(a["card"]), _iid(s, "p2", Types.CARD_FROZEN_BUNNY))


func test_passes_when_damage_is_small() -> void:
	var r: Array = _reaction_view(10, 5, [Types.CARD_MAGIC_SHIELD], Types.CARD_FIRE_ARROW, ["p2"])
	var s: Dictionary = r[0]
	var legal: Array = [Types.make_action_pass_reaction("p2"), _react(s, Types.CARD_MAGIC_SHIELD, ["p2"])]
	assert_eq(Bot.choose_among(r[1], "p2", legal, 1)["action"]["type"], Types.ACTION_PASS_REACTION)


func test_passes_when_spell_is_not_aimed_at_me() -> void:
	var r: Array = _reaction_view(2, 5, [Types.CARD_FROZEN_BUNNY], Types.CARD_FIREBALL, ["p3"])
	var s: Dictionary = r[0]
	var legal: Array = [Types.make_action_pass_reaction("p2"), _react(s, Types.CARD_FROZEN_BUNNY, ["p3"])]
	assert_eq(Bot.choose_among(r[1], "p2", legal, 1)["action"]["type"], Types.ACTION_PASS_REACTION)


func test_reacts_with_shield_on_high_damage_at_low_hp() -> void:
	var r: Array = _reaction_view(4, 5, [Types.CARD_MAGIC_SHIELD], Types.CARD_FIREBALL, ["p2"])
	var s: Dictionary = r[0]
	var legal: Array = [Types.make_action_pass_reaction("p2"), _react(s, Types.CARD_MAGIC_SHIELD, ["p2"])]
	assert_eq(Bot.choose_among(r[1], "p2", legal, 1)["action"]["type"], Types.ACTION_REACT)


func test_annihilation_must_target_the_spell() -> void:
	var r: Array = _reaction_view(2, 6, [Types.CARD_ANNIHILATION], Types.CARD_FIREBALL, ["p2"])
	var s: Dictionary = r[0]
	var legal: Array = [Types.make_action_pass_reaction("p2"), _react(s, Types.CARD_ANNIHILATION, [], 5),
		_react(s, Types.CARD_ANNIHILATION, [], 9999)]
	var a: Dictionary = Bot.choose_among(r[1], "p2", legal, 1)["action"]
	assert_eq(a["type"], Types.ACTION_REACT)
	assert_eq(int(a["target_card"]), 9999)


func test_drinks_potion_to_afford_lethal_defense() -> void:
	var r: Array = _reaction_view(2, 0, [Types.CARD_MAGIC_SHIELD], Types.CARD_FIREBALL, ["p2"])
	var legal: Array = [Types.make_action_pass_reaction("p2"), Types.make_action_drink_potion("p2")]
	var a: Dictionary = Bot.choose_among(r[1], "p2", legal, 1)["action"]
	assert_eq(a["type"], Types.ACTION_DRINK_POTION)


func test_does_not_double_defend_when_already_protected() -> void:
	var r: Array = _reaction_view(2, 6, [Types.CARD_MAGIC_SHIELD], Types.CARD_FIRE_ARROW, ["p2"])
	var s: Dictionary = r[0]
	var re: Dictionary = s["reaction"]
	(re["stack"] as Array).append(Types.make_spell({"iid": 8888, "card_id": Types.CARD_FROZEN_BUNNY}, "p2", ["p2"], {}, true))
	var legal: Array = [Types.make_action_pass_reaction("p2"), _react(s, Types.CARD_MAGIC_SHIELD, ["p2"])]
	var v: Dictionary = Types.view_for(s, "p2")
	assert_eq(Bot.choose_among(v, "p2", legal, 1)["action"]["type"], Types.ACTION_PASS_REACTION)


# --- V2-42: gestión de pociones (no atascarse con 10 de 10 y 0 de maná) -------

func test_heals_only_when_hp_is_low() -> void:
	var s: Dictionary = _setup(2, [Types.CARD_HEAL], 5)
	_set_hp(s, "p1", 3)
	assert_eq(_act(s)["type"], Types.ACTION_PLAY_CARD, "con 3 de vida cura")
	_set_hp(s, "p1", 6)
	assert_ne(_act(s)["type"], Types.ACTION_PLAY_CARD, "con 6 de vida no gasta maná en curar")


func test_no_heal_when_potions_are_scarce() -> void:
	var s: Dictionary = _setup(2, [Types.CARD_HEAL], 5)
	_set_hp(s, "p1", 3)
	H.player(s, "p1")["potions"] = Bot.SCARCE_POTIONS
	assert_true(Bot.is_scarce(s, "p1"))
	assert_ne(_act(s)["type"], Types.ACTION_PLAY_CARD, "con pocas pociones libres guarda el maná")


func test_scarce_potions_still_attacks() -> void:
	var s: Dictionary = _setup(2, [Types.CARD_LIGHTNING], 5)
	H.player(s, "p1")["potions"] = 9
	var a: Dictionary = _act(s)
	assert_eq(a["type"], Types.ACTION_PLAY_CARD)
	assert_eq(a["targets"], ["p2"])


func test_keeps_potion_reserve_when_drinking_to_play() -> void:
	var s: Dictionary = _setup(2, [Types.CARD_LIGHTNING], 1)
	H.player(s, "p1")["potions"] = 2
	assert_eq(_act(s)["type"], Types.ACTION_DRINK_POTION, "con margen bebe para atacar")
	H.player(s, "p1")["potions"] = int((s["config"] as Dictionary)["potion_limit"]) - Bot.DRINK_RESERVE
	assert_ne(_act(s)["type"], Types.ACTION_DRINK_POTION, "no gasta la reserva de pociones")


func test_drinks_into_reserve_only_for_a_kill() -> void:
	var s: Dictionary = _setup(2, [Types.CARD_LIGHTNING], 1)
	_set_hp(s, "p2", 2)
	H.player(s, "p1")["potions"] = int((s["config"] as Dictionary)["potion_limit"]) - Bot.DRINK_RESERVE
	assert_eq(_act(s)["type"], Types.ACTION_DRINK_POTION, "para matar sí usa la reserva")
	H.player(s, "p1")["potions"] = int((s["config"] as Dictionary)["potion_limit"])
	assert_ne(_act(s)["type"], Types.ACTION_DRINK_POTION, "nunca la poción que elimina")


func test_potion_limit_off_never_scarce() -> void:
	var s: Dictionary = _setup(2, [Types.CARD_HEAL], 5)
	(s["config"] as Dictionary)["potion_limit_enabled"] = false
	H.player(s, "p1")["potions"] = 9
	assert_false(Bot.is_scarce(s, "p1"))
