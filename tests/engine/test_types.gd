extends GutTest
## Contrato de tipos: constructores, validadores, vistas y normalización JSON.


func _sample_state() -> Dictionary:
	var s: Dictionary = Types.make_state({}, 7)
	var players: Array = s["players"]
	players.append(Types.make_player("p1", "Ana", 40, 3))
	players.append(Types.make_player("p2", "Beto", 30, 8, true))
	players.append(Types.make_player("p3", "Caro", 20, 12))
	var iid: int = 0
	for p: Variant in players:
		var pd: Dictionary = p
		for k: int in 2:
			(pd["hand"] as Array).append(Types.make_card_instance(iid, Types.CARD_FIRE_ARROW))
			iid += 1
	(Types.get_player(s, "p1")["artifacts"] as Array).append(
		Types.make_table_card(iid, Types.CARD_WILD_FIRE, "p1"))
	iid += 1
	for k: int in 4:
		(s["deck"] as Array).append(Types.make_card_instance(iid, Types.CARD_HEAL))
		iid += 1
	(s["discard"] as Array).append(Types.make_card_instance(iid, Types.CARD_FIREBALL))
	iid += 1
	s["active_event"] = Types.make_table_card(iid, Types.CARD_FIRE_STORM)
	iid += 1
	s["card_total"] = iid
	s["status"] = Types.STATUS_PLAYING
	s["turn"] = Types.make_turn(1, "p1", Types.PHASE_MAIN)
	(s["log"] as Array).append(Types.make_log_entry(Types.LOG_CARD_DRAWN, 1, "p1", {"card_id": "heal"}, ["p1"]))
	(s["log"] as Array).append(Types.make_log_entry(Types.LOG_TURN_STARTED, 1, "p1"))
	return s


func test_sample_state_is_valid() -> void:
	assert_eq(Types.validate_state(_sample_state()), [] as Array[String])


func test_empty_state_is_valid() -> void:
	assert_eq(Types.validate_state(Types.make_state()), [] as Array[String])


func test_validate_detects_problems() -> void:
	var s: Dictionary = _sample_state()
	Types.get_player(s, "p2")["hp"] = 11
	(s["deck"] as Array).append(Types.make_card_instance(0, Types.CARD_HEAL))  # iid duplicado
	s["rng_state"] = Types.RNG_MODULUS
	var errs: Array[String] = Types.validate_state(s)
	assert_eq(errs.size(), 4, str(errs))  # hp, rng, duplicado, conservación


func test_validate_rejects_floats() -> void:
	var s: Dictionary = _sample_state()
	Types.get_player(s, "p1")["mana"] = 2.0
	assert_false(Types.validate_state(s).is_empty())


func test_default_config_matches_decisions() -> void:
	var c: Dictionary = Types.default_config()
	assert_eq(c["potion_limit"], 10)
	assert_true(c["potion_limit_enabled"])
	assert_eq(c["potion_mana"], 3)
	assert_eq(c["reaction_timeout_online_ms"], 15000)
	assert_eq(c["reaction_timeout_local_ms"], 0)
	assert_eq(c["hand_limit"], 5)
	assert_eq(Types.make_config({"potion_limit": 4})["potion_limit"], 4)


func test_card_def_validation() -> void:
	var d: Dictionary = Types.make_card_def(Types.CARD_FIREBALL, "Fireball", Types.CARD_TYPE_OFFENSIVE,
		Types.ELEMENT_FIRE, 2, [Types.make_card_req(Types.REQ_BY_ELEMENT, Types.ELEMENT_FIRE)],
		Types.TARGET_SINGLE, 6, [19, 20, 21, 22, 23, 24])
	assert_eq(Types.validate_card_def(d), [] as Array[String])
	assert_true(d["is_spell"])
	d["element"] = "water"
	assert_eq(Types.validate_card_def(d).size(), 1)


func test_playable_ids_count() -> void:
	assert_eq(Types.PLAYABLE_CARD_IDS.size(), 58)
	var uniq: Dictionary = {}
	for id: String in Types.PLAYABLE_CARD_IDS:
		uniq[id] = true
	assert_eq(uniq.size(), 58)


func test_action_constructors_have_valid_shape() -> void:
	var actions: Array = [
		Types.make_action_play_card("p1", 3, ["p2"], [4]),
		Types.make_action_discard("p1", [1, 2]),
		Types.make_action_exchange("p1", 1),
		Types.make_action_drink_potion("p2"),
		Types.make_action_end_turn("p1"),
		Types.make_action_react("p2", 9),
		Types.make_action_pass_reaction("p3"),
		Types.make_action_break_rule("p1", "p2", 30),
		Types.make_action_choose_targets("p1", 5, ["p3"]),
		Types.make_action_choose_cards("p1", 5, [1]),
		Types.make_action_decline("p1", 5),
		Types.make_action_use_artifact("p1", 12),
		Types.make_action_use_event("p1", {"amount": 1}),
		Types.make_action_concede("p1"),
	]
	assert_eq(actions.size(), Types.ACTION_TYPES.size(), "un constructor por tipo")
	for a: Variant in actions:
		var ad: Dictionary = a
		assert_eq(Types.validate_action_shape(ad), Types.ERR_NONE, str(ad))
		# Sobrevive a JSON tras normalizar.
		var back: Dictionary = Types.normalize_value(JSON.parse_string(JSON.stringify(ad)))
		assert_eq(Types.validate_action_shape(back), Types.ERR_NONE, "JSON " + str(ad))
		assert_eq(back, ad)
	assert_eq(Types.validate_action_shape({"type": "NOPE", "player": "p1"}), Types.ERR_INVALID_ACTION)
	assert_eq(Types.validate_action_shape({"type": Types.ACTION_EXCHANGE, "player": "p1", "card": 1.5}),
		Types.ERR_INVALID_ACTION)


func test_normalize_json_roundtrip_is_identity() -> void:
	var s: Dictionary = _sample_state()
	var back: Dictionary = Types.normalize_state(JSON.parse_string(JSON.stringify(s)))
	assert_eq(back, s)
	assert_eq(typeof(Types.get_player(back, "p1")["hp"]), TYPE_INT)
	assert_eq(Types.validate_state(back), [] as Array[String])


func test_normalize_restores_firebase_dropped_keys() -> void:
	var s: Dictionary = _sample_state()
	var raw: Dictionary = JSON.parse_string(JSON.stringify(s))
	# Firebase borra arrays/diccionarios vacíos y convierte arrays en objetos a veces.
	raw.erase("modifiers")
	raw.erase("reaction")
	raw.erase("pending")
	raw.erase("winners")
	raw.erase("reveals")
	var p3: Dictionary = (raw["players"] as Array)[2]
	p3.erase("artifacts")
	p3.erase("curses")
	(p3["flags"] as Dictionary).erase("force_field")
	raw["discard"] = {"0": (raw["discard"] as Array)[0]}
	var back: Dictionary = Types.normalize_state(raw)
	assert_eq(back, s)


func test_public_view_hides_hidden_info() -> void:
	var s: Dictionary = _sample_state()
	var pub: Dictionary = Types.public_view(s)
	assert_eq(pub["deck"], [])
	assert_eq(pub["deck_count"], 4)
	assert_eq(pub["rng_state"], 0)
	for p: Variant in pub["players"]:
		var pd: Dictionary = p
		assert_eq(pd["hand"], [])
		assert_eq(pd["hand_count"], 2)
	assert_eq((pub["log"] as Array).size(), 1, "el robo privado no es público")
	assert_true(Types.is_json_safe(pub))
	assert_eq((s["deck"] as Array).size(), 4, "no muta el estado")


func test_private_and_composed_view() -> void:
	var s: Dictionary = _sample_state()
	var priv: Dictionary = Types.private_view(s, "p1")
	assert_eq((priv["hand"] as Array).size(), 2)
	assert_eq((priv["log"] as Array).size(), 1)
	var v: Dictionary = Types.view_for(s, "p1")
	assert_eq((Types.get_player(v, "p1")["hand"] as Array).size(), 2)
	assert_eq((Types.get_player(v, "p2")["hand"] as Array).size(), 0)
	assert_eq(Types.get_player(v, "p2")["hand_count"], 2)
	assert_eq((v["log"] as Array).size(), 2)
	var v2: Dictionary = Types.view_for(s, "p2")
	assert_eq((v2["log"] as Array).size(), 1, "p2 no ve el robo de p1")


func test_neighbors_skip_eliminated() -> void:
	var s: Dictionary = _sample_state()
	(s["players"] as Array).append(Types.make_player("p4", "Dani", 25, 5))
	assert_eq(Types.neighbors(s, "p1"), ["p4", "p2"] as Array[String])
	Types.get_player(s, "p2")["eliminated"] = true
	assert_eq(Types.neighbors(s, "p1"), ["p4", "p3"] as Array[String])
	assert_eq(Types.alive_ids(s), ["p1", "p3", "p4"] as Array[String])


func test_next_seq() -> void:
	var s: Dictionary = Types.make_state()
	assert_eq(Types.next_seq(s), 1)
	assert_eq(Types.next_seq(s), 2)
	assert_eq(s["seq"], 2)
