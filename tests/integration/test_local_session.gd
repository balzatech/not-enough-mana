extends NemTest
## T8: LocalSession (sin escenas). Creación desde LocalSetup, vistas, bots con
## temporizador cancelable, cola sin recursión, poción fuera de turno y
## temporizador de reacción.

const H = preload("res://tests/fixtures/engine_helpers.gd")

var _now: int = 1_000_000


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	UiUtil.prefer_extra = false


func _clock() -> int:
	return _now


func _setup(humans: int, bots: int, cfg: Dictionary = {}) -> Dictionary:
	var players: Array = []
	for i: int in humans + bots:
		players.append({"name": "Mago %d" % (i + 1), "age": 40 - i, "birth_month": i + 1, "is_bot": i >= humans})
	var c: Dictionary = {"potion_limit_enabled": true, "potion_limit": 10, "potion_mana": 3,
		"include_curse_of_rules": true, "reaction_timeout_local_ms": 0, "mode": "local"}
	for k: Variant in cfg:
		c[k] = cfg[k]
	return {"players": players, "config": c}


## p1 humano, p2 y p3 bots; turno de `turn_pid`. Manos vacías salvo las dadas.
func _scenario(turn_pid: String, hands: Dictionary, cfg: Dictionary = {}) -> LocalSession:
	var players: Array = [
		Types.make_player("p1", "Humano", 40, 1, false),
		Types.make_player("p2", "Bot A", 30, 2, true),
		Types.make_player("p3", "Bot B", 20, 3, true),
	]
	var s: Dictionary = Game.new_game(players, cfg, 77)
	for pid: String in ["p1", "p2", "p3"]:
		H.set_hand(s, pid, hands.get(pid, []) as Array)
		H.set_mana(s, pid, 6)
	H.force_turn(s, turn_pid)
	var ls: LocalSession = LocalSession.new()
	ls.auto_run_bots = false
	ls.clock = _clock
	ls.start(s, 5)
	return ls


func test_create_from_setup_hides_other_hands() -> void:
	var ls: LocalSession = LocalSession.create(_setup(1, 2), 42)
	autofree(ls)
	assert_eq(ls.get_local_player_ids(), ["p1"] as Array[String])
	assert_eq(ls.bot_ids(), ["p2", "p3"] as Array[String])
	assert_true(ls.is_authority())
	assert_eq(String(ls.state["status"]), Types.STATUS_PLAYING)
	assert_eq(String((ls.state["config"] as Dictionary)["mode"]), "local")
	var v: Dictionary = ls.get_view_for("p1")
	assert_true(bool(v["is_view"]))
	assert_gt((Types.get_player(v, "p1")["hand"] as Array).size(), 0)
	assert_eq((Types.get_player(v, "p2")["hand"] as Array).size(), 0, "mano ajena oculta")
	assert_eq((v["deck"] as Array).size(), 0, "mazo oculto")
	assert_true(Types.get_player(ls.state, "p2")["is_bot"])


func test_ui_nav_uses_local_session_by_default() -> void:
	var prev: Callable = UiNav.session_factory
	UiNav.session_factory = Callable()
	var s: GameSession = UiNav.make_local_session(_setup(2, 1))
	assert_true(s is LocalSession)
	assert_eq(s.get_local_player_ids().size(), 2)
	s.free()
	UiNav.session_factory = prev


func test_bots_play_until_a_human_decides() -> void:
	var ls: LocalSession = LocalSession.create(_setup(1, 2), 7)
	autofree(ls)
	ls.auto_run_bots = false
	var guard: int = 0
	while String(ls.state["status"]) == Types.STATUS_PLAYING and guard < 50:
		guard += 1
		if Decision.local_decider(ls.state, ls.get_local_player_ids()) == "p1":
			ls.submit_action(LocalSession.safe_action(ls.state, "p1"))
		else:
			ls.run_bots(30)
	for h: Dictionary in ls.history:
		if String(h["by"]) == "bot":
			assert_eq(String(h["error"]), "", "acción de bot legal: %s" % JSON.stringify(h["action"]))
	assert_gt(ls.history.size(), 5)


func test_bot_timer_is_cancelable_and_acts_after_delay() -> void:
	var ls: LocalSession = _scenario("p2", {"p2": [Types.CARD_HEAL]})
	ls.auto_run_bots = true
	ls.bot_delay_min_ms = 30
	ls.bot_delay_max_ms = 40
	add_child_autofree(ls)
	await wait_process_frames(1)
	assert_true(ls.bot_pending(), "hay una acción de bot programada")
	var rev0: int = ls.get_rev()
	ls.cancel_bot()
	assert_false(ls.bot_pending())
	await wait_seconds(0.15)
	assert_eq(ls.get_rev(), rev0, "cancelado: el bot no actúa")
	ls._schedule()
	await wait_seconds(0.3)
	assert_gt(ls.get_rev(), rev0, "el bot actuó tras el retraso")


func test_submit_from_signal_handler_is_queued_not_recursive() -> void:
	var ls: LocalSession = _scenario("p1", {"p1": [Types.CARD_HEAL]})
	autofree(ls)
	var calls: Array[int] = []
	var depth: Array[int] = [0]
	ls.state_changed.connect(func(_rev: int, _ev: Array) -> void:
		depth[0] += 1
		calls.append(depth[0])
		if calls.size() < 4:
			ls.submit_action(Types.make_action_drink_potion("p1"))
		depth[0] -= 1)
	ls.submit_action(Types.make_action_drink_potion("p1"))
	assert_eq(calls.size(), 4, "cuatro pociones aplicadas")
	for d: int in calls:
		assert_eq(d, 1, "sin recursión: cada señal se emite fuera de la anterior")
	assert_eq(int(Types.get_player(ls.state, "p1")["potions"]), 4)


func test_drink_potion_out_of_turn() -> void:
	var ls: LocalSession = _scenario("p2", {"p2": [Types.CARD_HEAL]})
	autofree(ls)
	var errors: Array[String] = []
	ls.error.connect(func(code: String, _a: Dictionary) -> void: errors.append(code))
	var mana0: int = int(Types.get_player(ls.state, "p1")["mana"])
	ls.submit_action(Types.make_action_drink_potion("p1"))
	assert_eq(errors, [] as Array[String])
	assert_eq(int(Types.get_player(ls.state, "p1")["potions"]), 1)
	assert_eq(int(Types.get_player(ls.state, "p1")["mana"]), mana0 + 3)
	ls.submit_action(Types.make_action_end_turn("p1"))
	assert_eq(errors, [Types.ERR_NOT_YOUR_TURN] as Array[String], "error en español disponible")
	assert_eq(UiUtil.error_text(errors[0]), "No es tu turno.")


func test_safe_action_fallback() -> void:
	var ls: LocalSession = _scenario("p2", {"p2": [Types.CARD_HEAL]})
	autofree(ls)
	var a: Dictionary = LocalSession.safe_action(ls.state, "p2")
	assert_eq(String(a["type"]), Types.ACTION_END_TURN)
	assert_eq(LocalSession.safe_action(ls.state, "p3"), {}, "p3 no tiene nada que decidir")


func test_reaction_timeout_passes_for_the_human() -> void:
	var ls: LocalSession = _scenario("p2", {"p1": [Types.CARD_MAGIC_SHIELD], "p2": [Types.CARD_FIRE_ARROW]},
		{"reaction_timeout_local_ms": 5000})
	autofree(ls)
	var opened: Array[Dictionary] = []
	ls.reaction_opened.connect(func(r: Dictionary) -> void: opened.append(r))
	ls._enqueue(Types.make_action_play_card("p2", int(H.hand(ls.state, "p2")[0]["iid"]), ["p1"]), "bot")
	var re: Dictionary = ls.state["reaction"]
	assert_false(re.is_empty(), "ventana abierta")
	assert_eq(opened.size(), 1)
	assert_eq(Decision.responder(ls.state), "p1")
	assert_eq(int(re["deadline_ms"]), _now + 5000, "plazo fijado por la sesión")
	assert_true(bool(ls.get_view_for("p1")["reaction"]["deadline_ms"] > 0), "la vista lleva el plazo")
	assert_false(ls.check_timeouts(), "aún no vence")
	_now += 5001
	assert_true(ls.check_timeouts())
	assert_true((ls.state["reaction"] as Dictionary).is_empty(), "se cerró la ventana")
	var found: bool = false
	for h: Dictionary in ls.history:
		if String(h["by"]) == "timeout":
			found = true
			assert_eq(String((h["action"] as Dictionary)["type"]), Types.ACTION_PASS_REACTION)
			assert_eq(String((h["action"] as Dictionary)["player"]), "p1")
	assert_true(found, "PASS_REACTION enviado por el temporizador")
	assert_eq(int(Types.get_player(ls.state, "p1")["hp"]), 9, "Fire Arrow resuelto: 1 de daño")


func test_no_deadline_without_local_timer() -> void:
	var ls: LocalSession = _scenario("p2", {"p1": [Types.CARD_MAGIC_SHIELD], "p2": [Types.CARD_FIRE_ARROW]})
	autofree(ls)
	ls._enqueue(Types.make_action_play_card("p2", int(H.hand(ls.state, "p2")[0]["iid"]), ["p1"]), "bot")
	assert_eq(int((ls.state["reaction"] as Dictionary)["deadline_ms"]), 0, "sin temporizador: botón Pasar")
	_now += 100000
	assert_false(ls.check_timeouts())


func test_game_over_signal_once() -> void:
	var ls: LocalSession = _scenario("p1", {"p1": [Types.CARD_HEAL]})
	autofree(ls)
	var overs: Array[Array] = []
	ls.game_over.connect(func(w: Array) -> void: overs.append(w))
	ls.submit_action(Types.make_action_concede("p2"))
	ls.submit_action(Types.make_action_concede("p3"))
	assert_eq(String(ls.state["status"]), Types.STATUS_FINISHED)
	assert_eq(overs.size(), 1)
	assert_eq(overs[0], ["p1"])
	ls.submit_action(Types.make_action_drink_potion("p1"))
	assert_eq(overs.size(), 1, "una sola vez")
	assert_false(ls.step_bot(), "los bots no actúan con la partida terminada")
