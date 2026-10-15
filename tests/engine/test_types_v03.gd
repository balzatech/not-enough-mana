extends GutTest
## V3-13b: contrato de la v0.3 en Types (acción TIMEOUT, plazos en la config y
## helpers de tamaños ocultos deck_size / hand_size de la regla A1).


func before_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func _sample_state() -> Dictionary:
	var s: Dictionary = Types.make_state({}, 11)
	var players: Array = s["players"]
	players.append(Types.make_player("p1", "Ana", 40, 3))
	players.append(Types.make_player("p2", "Beto", 30, 8, true))
	players.append(Types.make_player("p3", "Caro", 20, 12))
	var iid: int = 0
	var sizes: Dictionary = {"p1": 3, "p2": 1, "p3": 0}
	for pid: String in sizes:
		for k: int in int(sizes[pid]):
			(Types.get_player(s, pid)["hand"] as Array).append(Types.make_card_instance(iid, Types.CARD_HEAL))
			iid += 1
	for k: int in 6:
		(s["deck"] as Array).append(Types.make_card_instance(iid, Types.CARD_FIRE_ARROW))
		iid += 1
	s["card_total"] = iid
	s["status"] = Types.STATUS_PLAYING
	s["turn"] = Types.make_turn(1, "p1", Types.PHASE_MAIN)
	return s


func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))


# -----------------------------------------------------------------------------
# Acción TIMEOUT
# -----------------------------------------------------------------------------

func test_timeout_constants() -> void:
	assert_eq(Types.ACTION_TIMEOUT, "TIMEOUT")
	assert_eq(Types.LOG_TIMEOUT, "timeout")
	assert_eq(Types.ERR_TIMEOUT_STALE, "timeout_stale")
	assert_eq(Types.TIMEOUT_SCOPES, ["turn", "reaction", "prompt"] as Array[String])
	assert_eq(Types.SESSION_ACTION_TYPES, [Types.ACTION_TIMEOUT] as Array[String])


func test_timeout_is_not_a_player_action() -> void:
	assert_false(Types.ACTION_TYPES.has(Types.ACTION_TIMEOUT), "no es una acción de jugador")
	assert_false(Types.OUT_OF_TURN_ACTIONS.has(Types.ACTION_TIMEOUT))
	for t: String in Types.ACTION_TYPES + Types.SESSION_ACTION_TYPES:
		assert_true(Types.ACTION_SPECS.has(t), "spec de " + t)
	assert_eq(Types.ACTION_SPECS.size(), Types.ACTION_TYPES.size() + Types.SESSION_ACTION_TYPES.size())


func test_make_action_timeout_defaults() -> void:
	var a: Dictionary = Types.make_action_timeout("p2", Types.TIMEOUT_SCOPE_PROMPT)
	assert_eq(a, {"type": "TIMEOUT", "player": "p2", "scope": "prompt", "prompt_id": -1, "expect": {}})
	assert_eq(Types.validate_action_shape(a), Types.ERR_NONE)


func test_make_action_timeout_shapes_survive_json() -> void:
	var actions: Array = [
		Types.make_action_timeout("p1", Types.TIMEOUT_SCOPE_TURN, -1, {"turn": 4}),
		Types.make_action_timeout("p2", Types.TIMEOUT_SCOPE_REACTION, -1, {"spell_iid": 17, "stack": 2}),
		Types.make_action_timeout("p3", Types.TIMEOUT_SCOPE_PROMPT, 9),
	]
	for a: Variant in actions:
		var ad: Dictionary = a
		assert_eq(Types.validate_action_shape(ad), Types.ERR_NONE, str(ad))
		var back: Dictionary = Types.normalize_value(_json(ad))
		assert_eq(back, ad, "JSON " + str(ad))
		assert_eq(Types.validate_action_shape(back), Types.ERR_NONE)
		assert_eq(typeof((back["expect"] as Dictionary).get("turn", 0)), TYPE_INT)


func test_make_action_timeout_copies_expect() -> void:
	var expect: Dictionary = {"turn": 2}
	var a: Dictionary = Types.make_action_timeout("p1", Types.TIMEOUT_SCOPE_TURN, -1, expect)
	expect["turn"] = 99
	assert_eq(int((a["expect"] as Dictionary)["turn"]), 2)


func test_timeout_shape_rejects_bad_fields() -> void:
	var good: Dictionary = Types.make_action_timeout("p1", Types.TIMEOUT_SCOPE_TURN, -1, {"turn": 1})
	for k: String in ["scope", "prompt_id", "expect"]:
		var missing: Dictionary = good.duplicate(true)
		missing.erase(k)
		assert_eq(Types.validate_action_shape(missing), Types.ERR_INVALID_ACTION, "sin " + k)
	var bad: Dictionary = good.duplicate(true)
	bad["prompt_id"] = "1"
	assert_eq(Types.validate_action_shape(bad), Types.ERR_INVALID_ACTION)
	bad = good.duplicate(true)
	bad["expect"] = []
	assert_eq(Types.validate_action_shape(bad), Types.ERR_INVALID_ACTION)


func test_legal_actions_never_offer_timeout() -> void:
	var players: Array = []
	for i: int in 4:
		players.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 30, i + 1))
	var s: Dictionary = Game.new_game(players, {}, 5)
	var seen: int = 0
	for step: int in 120:
		if String(s["status"]) != Types.STATUS_PLAYING:
			break
		var chosen: Dictionary = {}
		for pid: String in Types.alive_ids(s):
			var sources: Array = [s, Types.view_for(s, pid)]
			for i: int in sources.size():
				for a: Variant in Game.legal_actions(sources[i] as Dictionary, pid):
					var ad: Dictionary = a
					seen += 1
					assert_ne(String(ad["type"]), Types.ACTION_TIMEOUT)
					if i == 0 and chosen.is_empty() and String(ad["type"]) != Types.ACTION_CONCEDE:
						chosen = ad
		if chosen.is_empty():
			break
		var r: Dictionary = Game.reduce(s, chosen)
		if String(r["error"]) != Types.ERR_NONE:
			break
		s = r["state"]
	assert_gt(seen, 50, "se revisaron acciones legales")


# -----------------------------------------------------------------------------
# Config: turn_timeout_ms / defense_timeout_ms
# -----------------------------------------------------------------------------

func test_timeout_config_defaults_to_no_limit() -> void:
	var c: Dictionary = Types.default_config()
	assert_eq(c["turn_timeout_ms"], 0)
	assert_eq(c["defense_timeout_ms"], 0)
	assert_eq(c["reaction_timeout_local_ms"], 0, "la clave de v0.2 se conserva")
	var o: Dictionary = Types.make_config({"turn_timeout_ms": 30000, "defense_timeout_ms": 20000})
	assert_eq(o["turn_timeout_ms"], 30000)
	assert_eq(o["defense_timeout_ms"], 20000)


func test_validate_state_requires_timeout_keys() -> void:
	var s: Dictionary = _sample_state()
	assert_eq(Types.validate_state(s), [] as Array[String])
	(s["config"] as Dictionary).erase("turn_timeout_ms")
	assert_false(Types.validate_state(s).is_empty())


func test_normalize_fills_missing_timeout_keys() -> void:
	var s: Dictionary = _sample_state()
	var cfg: Dictionary = s["config"]
	cfg.erase("turn_timeout_ms")
	cfg.erase("defense_timeout_ms")
	var back: Dictionary = Types.normalize_state(_json(s))
	var bcfg: Dictionary = back["config"]
	assert_eq(bcfg["turn_timeout_ms"], 0)
	assert_eq(bcfg["defense_timeout_ms"], 0)
	assert_eq(typeof(bcfg["turn_timeout_ms"]), TYPE_INT)
	assert_eq(Types.validate_state(back), [] as Array[String])


func test_normalize_keeps_timeout_values_as_int() -> void:
	var s: Dictionary = _sample_state()
	s["config"] = Types.make_config({"turn_timeout_ms": 30000, "defense_timeout_ms": 20000})
	var back: Dictionary = Types.normalize_state(_json(s))
	assert_eq(back, s, "ida y vuelta idéntica")
	assert_eq(typeof((back["config"] as Dictionary)["defense_timeout_ms"]), TYPE_INT)
	assert_eq(Types.normalize_state(back), back, "idempotente")


# -----------------------------------------------------------------------------
# deck_size / hand_size (A1)
# -----------------------------------------------------------------------------

func test_sizes_on_full_state() -> void:
	var s: Dictionary = _sample_state()
	assert_eq(Types.deck_size(s), 6)
	assert_eq(Types.hand_size(s, "p1"), 3)
	assert_eq(Types.hand_size(s, "p2"), 1)
	assert_eq(Types.hand_size(s, "p3"), 0)
	assert_eq(Types.hand_size(s, "nadie"), 0)


func test_sizes_match_on_every_view() -> void:
	var s: Dictionary = _sample_state()
	var views: Array = [Types.public_view(s), Bot.make_view(s, "p2")]
	for pid: String in ["p1", "p2", "p3"]:
		views.append(Types.view_for(s, pid))
		views.append(Types.compose_view(Types.public_view(s), Types.private_view(s, pid), pid))
	for v: Variant in views:
		var vd: Dictionary = v
		assert_true(bool(vd["is_view"]))
		assert_eq((vd["deck"] as Array).size(), 0, "el mazo no viaja en la vista")
		assert_eq(Types.deck_size(vd), Types.deck_size(s))
		for pid: String in ["p1", "p2", "p3", "nadie"]:
			assert_eq(Types.hand_size(vd, pid), Types.hand_size(s, pid), pid)


func test_sizes_after_json_and_normalize_on_view() -> void:
	var s: Dictionary = _sample_state()
	var v: Dictionary = Types.normalize_state(_json(Types.view_for(s, "p3")))
	assert_eq(Types.deck_size(v), 6)
	assert_eq(Types.hand_size(v, "p1"), 3)
	assert_eq(Types.hand_size(v, "p3"), 0)
	# Mazo vacío: deck_count = 0 sobrevive (Firebase solo borra [], {} y null).
	(s["deck"] as Array).clear()
	var empty: Dictionary = Types.normalize_state(_json(Types.public_view(s)))
	assert_eq(Types.deck_size(empty), 0)
	assert_eq(Types.deck_size(s), 0)


func test_sizes_on_game_in_progress() -> void:
	var players: Array = []
	for i: int in 3:
		players.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 30, i + 1))
	var s: Dictionary = Game.new_game(players, {}, 3)
	for pid: String in ["p1", "p2", "p3"]:
		var v: Dictionary = Types.view_for(s, pid)
		assert_eq(Types.deck_size(v), (s["deck"] as Array).size())
		for other: String in ["p1", "p2", "p3"]:
			assert_eq(Types.hand_size(v, other), (Types.get_player(s, other)["hand"] as Array).size())
