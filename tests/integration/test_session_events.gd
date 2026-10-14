extends GutTest
## V2-14a: LocalSession emite en state_changed las entradas de log nuevas
## (por log_seq), respetando visible_to.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func _session(humans: int, bots: int, cfg: Dictionary = {}) -> LocalSession:
	var players: Array = []
	for i: int in humans + bots:
		players.append({"name": "Mago %d" % (i + 1), "age": 40 - i, "birth_month": i + 1, "is_bot": i >= humans})
	var c: Dictionary = {"potion_limit_enabled": true, "potion_limit": 10, "potion_mana": 3,
		"include_curse_of_rules": true, "reaction_timeout_local_ms": 0, "mode": "local", "log_limit": 100000}
	for k: Variant in cfg:
		c[k] = cfg[k]
	var ls: LocalSession = LocalSession.create({"players": players, "config": c}, 33)
	autofree(ls)
	ls.auto_run_bots = false
	return ls


func test_not_enough_mana_entry_is_numbered_and_emitted() -> void:
	var players: Array = [Types.make_player("p1", "Humano", 40, 1, false),
		Types.make_player("p2", "Bot", 30, 2, true)]
	var s: Dictionary = Game.new_game(players, {"log_limit": 1000}, 5)
	for pid: String in ["p1", "p2"]:
		H.set_hand(s, pid, [])
		H.set_mana(s, pid, 6)
	H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW])
	X.event(s, Types.CARD_NOT_ENOUGH_MANA)
	H.force_turn(s, "p2")
	var ls: LocalSession = LocalSession.new()
	autofree(ls)
	ls.auto_run_bots = false
	ls.start(s, 5)
	var got: Array = []
	ls.state_changed.connect(func(_r: int, ev: Array) -> void: got.append_array(ev))
	ls._enqueue(Types.make_action_play_card("p2", int(H.hand(ls.state, "p2")[0]["iid"]), ["p1"]), "bot")
	var guard: int = 0
	while not (ls.state["reaction"] as Dictionary).is_empty() and guard < 10:
		guard += 1
		ls._enqueue(Types.make_action_pass_reaction(Decision.responder(ls.state)), "bot")
	var mana_entries: Array = []
	for e: Variant in got:
		var ed: Dictionary = e
		assert_gt(int(ed["log_seq"]), 0)
		if String(ed["type"]) == Types.LOG_MANA_CHANGED and int((ed["data"] as Dictionary)["delta"]) < 0:
			mana_entries.append(ed)
	assert_eq(mana_entries.size(), 1, "la entrada de maná de Not Enough Mana llega a la UI")
	assert_eq(Types.last_log_seq(got), Types.last_log_seq(ls.state["log"] as Array))


func test_union_of_events_equals_public_log_in_bot_game() -> void:
	var ls: LocalSession = _session(0, 4)
	var got: Array = []
	ls.state_changed.connect(func(_r: int, ev: Array) -> void: got.append_array(ev))
	var base: int = Types.last_log_seq(ls.state["log"] as Array)
	ls.run_bots(300)
	var expected: Array = []
	for e: Variant in ls.state["log"]:
		if int((e as Dictionary)["log_seq"]) > base and ((e as Dictionary)["visible_to"] as Array).is_empty():
			expected.append(int((e as Dictionary)["log_seq"]))
	var seqs: Array = []
	for e: Variant in got:
		seqs.append(int((e as Dictionary)["log_seq"]))
	assert_gt(seqs.size(), 20)
	assert_eq(seqs, expected, "mismo orden, sin duplicados")


func test_private_entry_only_reaches_the_local_human() -> void:
	var ls: LocalSession = _session(2, 1)
	var got: Array = []
	ls.state_changed.connect(func(_r: int, ev: Array) -> void: got.append_array(ev))
	var iid: int = int(H.hand(ls.state, "p1")[0]["iid"])
	var entry: Dictionary = Types.make_log_entry(Types.LOG_CARD_DRAWN, 1, "p1", {"iid": iid}, ["p1"])
	var bot_entry: Dictionary = Types.make_log_entry(Types.LOG_CARD_DRAWN, 1, "p3", {"iid": 1}, ["p3"])
	Game._append_log(ls.state, [entry, bot_entry])
	ls._after_change([])
	var mine: int = 0
	for e: Variant in got:
		var ed: Dictionary = e
		if String(ed["type"]) == Types.LOG_CARD_DRAWN:
			assert_false((ed["visible_to"] as Array).has("p3"), "la privada del bot no llega")
			mine += 1
	assert_eq(mine, 1, "la privada de p1 llega una vez")
	got.clear()
	ls._after_change([])
	assert_eq(got.size(), 0, "sin duplicados")
