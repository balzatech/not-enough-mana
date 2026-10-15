extends NemTest
## V2-25b: auto-pase de reacción en LocalSession (R1, R11, R12, R14, plazo).

const H = preload("res://tests/fixtures/engine_helpers.gd")


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


## n jugadores; los primeros `humans` son humanos. El lanzador (caster) tiene un
## Fireball; todos tienen mana de sobra y un Magic Shield (sin reacciones posibles no hay ventana).
func _session(n: int, humans: int, caster: String, mode: String, cfg: Dictionary = {}) -> LocalSession:
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), "Mago %d" % (i + 1), 40 - i, i + 1, i >= humans))
	var c: Dictionary = {"log_limit": 100000, "reaction_timeout_local_ms": 0}
	for k: Variant in cfg:
		c[k] = cfg[k]
	var s: Dictionary = Game.new_game(players, c, 7)
	for p: Variant in players:
		var pid: String = String((p as Dictionary)["id"])
		H.set_hand(s, pid, [Types.CARD_MAGIC_SHIELD])  # algo con que reaccionar: abre la ventana
		H.set_mana(s, pid, 6)
	H.set_hand(s, caster, [Types.CARD_FIRE_ARROW])
	H.force_turn(s, caster)
	var ls: LocalSession = LocalSession.new()
	autofree(ls)
	ls.auto_run_bots = false
	ls.clock = func() -> int: return 1000
	ls.reaction_notify = mode
	ls.start(s, 7)
	return ls


## Lanza la carta y deja pasar a los bots que deciden antes. Devuelve los pases de bot.
func _cast(ls: LocalSession, caster: String, target: String) -> int:
	var iid: int = int(H.hand(ls.state, caster)[0]["iid"])
	ls._enqueue(Types.make_action_play_card(caster, iid, [target]), "bot")
	return _bots_pass(ls)


## Los bots que deciden en la ventana pasan, de uno en uno, hasta que decide un
## humano o se cierra. Devuelve cuántos pases de bot se enviaron.
func _bots_pass(ls: LocalSession) -> int:
	var n: int = 0
	while not (ls.state["reaction"] as Dictionary).is_empty() and ls.is_bot(Decision.responder(ls.state)) and n < 10:
		ls._enqueue(Types.make_action_pass_reaction(Decision.responder(ls.state)), "bot")
		n += 1
	return n


func _autos(ls: LocalSession) -> Array:
	var out: Array = []
	for h: Dictionary in ls.history:
		if String(h["by"]) == "auto_pass":
			out.append(h)
	return out


func test_default_mode_is_all() -> void:
	var ls: LocalSession = LocalSession.new()
	autofree(ls)
	assert_eq(ls.reaction_notify, "all")


func test_r1_unaffected_human_is_auto_passed_once() -> void:
	var ls: LocalSession = _session(3, 1, "p2", "affecting")
	_cast(ls, "p2", "p3")
	var autos: Array = _autos(ls)
	assert_eq(autos.size(), 1)
	assert_eq(String((autos[0]["action"] as Dictionary)["type"]), Types.ACTION_PASS_REACTION)
	assert_eq(String((autos[0]["action"] as Dictionary)["player"]), "p1")
	assert_eq(String(autos[0]["error"]), "")
	# Igual que pasar a mano en modo "all"
	var manual: LocalSession = _session(3, 1, "p2", "all")
	_cast(manual, "p2", "p3")
	assert_eq(Decision.responder(manual.state), "p1")
	manual._enqueue(Types.make_action_pass_reaction("p1"), "human")
	assert_eq(ls.state["reaction"], manual.state["reaction"])
	assert_eq(ls.state["players"], manual.state["players"])


func test_r1_emits_new_log_entries_once() -> void:
	var ls: LocalSession = _session(3, 1, "p2", "affecting")
	var got: Array = []
	var revs: Array = []
	ls.state_changed.connect(func(r: int, ev: Array) -> void:
		revs.append(r)
		got.append_array(ev))
	var passes: int = _cast(ls, "p2", "p3")
	assert_eq(revs.size(), 1 + passes, "una emision por accion enviada: el estado intermedio no sale")
	assert_eq(int(revs.back()), ls.get_rev())
	var seqs: Array = []
	for e: Variant in got:
		seqs.append(int((e as Dictionary)["log_seq"]))
	var uniq: Array = []
	for q: Variant in seqs:
		if not uniq.has(q):
			uniq.append(q)
	assert_eq(seqs, uniq, "sin duplicados")
	assert_eq(int(seqs.max()), Types.last_log_seq(ls.state["log"] as Array))


func test_r1_human_never_seen_as_responder_when_unaffected() -> void:
	var ls: LocalSession = _session(3, 1, "p2", "affecting")
	var bad: Array = [0]
	ls.state_changed.connect(func(_r: int, _ev: Array) -> void:
		if not (ls.state["reaction"] as Dictionary).is_empty() and Decision.responder(ls.state) == "p1":
			bad[0] += 1)
	_cast(ls, "p2", "p3")
	assert_eq(bad[0], 0)


func test_r1_affected_human_is_not_auto_passed() -> void:
	var ls: LocalSession = _session(3, 1, "p2", "affecting")
	_cast(ls, "p2", "p1")
	assert_eq(_autos(ls).size(), 0)
	assert_eq(Decision.responder(ls.state), "p1")


func test_r11_mode_all_never_auto_passes() -> void:
	var ls: LocalSession = _session(3, 1, "p2", "all")
	_cast(ls, "p2", "p3")
	assert_eq(_autos(ls).size(), 0)
	assert_eq(Decision.responder(ls.state), "p1")


func test_r12_two_local_humans_two_auto_passes() -> void:
	var ls: LocalSession = _session(4, 2, "p4", "affecting")
	var bad: Array = [0]
	ls.state_changed.connect(func(_r: int, _ev: Array) -> void:
		if not (ls.state["reaction"] as Dictionary).is_empty() \
				and ["p1", "p2"].has(Decision.responder(ls.state)):
			bad[0] += 1)
	_cast(ls, "p4", "p3")
	assert_eq(_autos(ls).size(), 2)
	assert_eq(bad[0], 0)


func test_r12_loop_is_bounded() -> void:
	# Con todos los humanos no afectados el bucle termina (tope = jugadores x 4).
	var ls: LocalSession = _session(4, 3, "p4", "affecting")
	_cast(ls, "p4", "p1")
	assert_lte(_autos(ls).size(), 16)


func test_r14_pending_prompt_blocks_auto_pass() -> void:
	var ls: LocalSession = _session(3, 1, "p2", "affecting")
	_cast(ls, "p2", "p3")
	var view: Dictionary = ls.state.duplicate(true)
	view["reaction"] = {"spell": {"card": {"card_id": Types.CARD_FIRE_ARROW, "iid": 1}, "caster": "p2",
		"targets": ["p3"]}, "stack": []}
	view["pending"] = [{"id": 1, "player": "p1", "type": Types.PROMPT_DISCARD, "data": {}}]
	var a: Dictionary = ReactionRelevance.auto_pass_action(view, ["p1"] as Array[String], "affecting")
	assert_true(a.is_empty())


func test_deadline_not_started_for_auto_passed_player() -> void:
	var ls: LocalSession = _session(3, 1, "p2", "affecting", {"reaction_timeout_local_ms": 5000})
	_cast(ls, "p2", "p3")
	assert_eq(_autos(ls).size(), 1)
	assert_ne(ls._deadline_owner, "p1")
	assert_true(ls._reaction_timer.is_stopped())
	var re: Dictionary = ls.state["reaction"] as Dictionary
	assert_false(not re.is_empty() and Decision.responder(ls.state) == "p1")


func test_deadline_still_set_in_mode_all() -> void:
	var ls: LocalSession = _session(3, 1, "p2", "all", {"reaction_timeout_local_ms": 5000})
	_cast(ls, "p2", "p3")
	assert_eq(ls._deadline_owner, "p1")
	assert_eq(int((ls.state["reaction"] as Dictionary)["deadline_ms"]), 6000)
