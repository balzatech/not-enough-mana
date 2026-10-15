extends NemTest
## V2-14a: numeración del log (log_seq) en Game._append_log.

const H = preload("res://tests/fixtures/engine_helpers.gd")


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func _play_bots(cfg: Dictionary, steps: int) -> LocalSession:
	var players: Array = []
	for i: int in 4:
		players.append({"name": "Bot %d" % i, "age": 40 - i, "birth_month": i + 1, "is_bot": true})
	var c: Dictionary = {"potion_limit_enabled": true, "potion_limit": 10, "potion_mana": 3,
		"include_curse_of_rules": true, "reaction_timeout_local_ms": 0, "mode": "local"}
	for k: Variant in cfg:
		c[k] = cfg[k]
	var ls: LocalSession = LocalSession.create({"players": players, "config": c}, 21)
	autofree(ls)
	ls.auto_run_bots = false
	ls.run_bots(steps)
	return ls


func test_log_seq_is_consecutive_from_one() -> void:
	var ls: LocalSession = _play_bots({"log_limit": 100000}, 30)
	var log_entries: Array = ls.state["log"]
	assert_gt(log_entries.size(), 10)
	for i: int in log_entries.size():
		assert_eq(int((log_entries[i] as Dictionary)["log_seq"]), i + 1, "entrada %d" % i)


func test_log_seq_survives_trimming() -> void:
	var ls: LocalSession = _play_bots({"log_limit": 10}, 40)
	var log_entries: Array = ls.state["log"]
	assert_eq(log_entries.size(), 10)
	var first: int = int((log_entries[0] as Dictionary)["log_seq"])
	assert_gt(first, 1, "se recortó")
	for i: int in log_entries.size():
		assert_eq(int((log_entries[i] as Dictionary)["log_seq"]), first + i)
