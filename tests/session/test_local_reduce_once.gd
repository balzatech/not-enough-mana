extends NemTest
## Una accion de bot llama a Game.reduce una sola vez (el reduce de validacion se
## reutiliza en _apply) y el resultado es identico al flujo antiguo (dos reduce).


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func _session(n: int, humans: int, seed_value: int, reuse: bool, mode: String = "all") -> LocalSession:
	var players: Array = []
	for i: int in n:
		players.append({"name": "Mago %d" % (i + 1), "age": 30 + i, "birth_month": i + 1, "is_bot": i >= humans})
	var setup: Dictionary = {"players": players, "config": {"potion_limit_enabled": true, "potion_limit": 10,
		"potion_mana": 3, "reaction_timeout_local_ms": 0}}
	var ls: LocalSession = LocalSession.create(setup, seed_value)
	autofree(ls)
	ls.auto_run_bots = false
	ls.bot_randomness = 0 if humans == 0 else 15
	ls.reuse_bot_reduce = reuse
	ls.reaction_notify = mode
	return ls


## Ejecuta hasta max_steps acciones de bot y devuelve una huella del resultado.
func _trace(ls: LocalSession, max_steps: int) -> Dictionary:
	var revs: Array = []
	ls.state_changed.connect(func(rev: int, shown: Array) -> void: revs.append([rev, shown.size()]))
	var applied: int = ls.run_bots(max_steps)
	return {"applied": applied, "state": JSON.stringify(ls.state), "history": JSON.stringify(ls.history),
		"revs": JSON.stringify(revs), "rev": ls.get_rev()}


func test_one_reduce_per_bot_action() -> void:
	var ls: LocalSession = _session(3, 0, 5, true)
	var before: int = ls.reduce_calls
	for _i: int in 40:
		var c0: int = ls.reduce_calls
		if not ls.step_bot():
			break
		assert_eq(ls.reduce_calls - c0, 1, "una sola llamada a Game.reduce por accion de bot")
	assert_gt(ls.reduce_calls, before + 20, "se aplicaron acciones")


func test_old_flow_did_two_reduces() -> void:
	var ls: LocalSession = _session(3, 0, 5, false)
	var c0: int = ls.reduce_calls
	assert_true(ls.step_bot())
	assert_eq(ls.reduce_calls - c0, 2, "el flujo de referencia valida y vuelve a reducir")


func test_same_result_as_old_flow_bots_only() -> void:
	for np: int in [3, 6]:
		for sd: int in [1, 2, 3]:
			var a: Dictionary = _trace(_session(np, 0, sd, true), 400)
			var b: Dictionary = _trace(_session(np, 0, sd, false), 400)
			assert_gt(int(a["applied"]), 50, "%dj semilla %d: hubo acciones" % [np, sd])
			assert_eq(a["applied"], b["applied"], "%dj s%d: mismas acciones" % [np, sd])
			assert_eq(a["rev"], b["rev"], "%dj s%d: mismo rev" % [np, sd])
			assert_true(a["state"] == b["state"], "%dj s%d: mismo estado" % [np, sd])
			assert_true(a["history"] == b["history"], "%dj s%d: mismo historial" % [np, sd])
			assert_true(a["revs"] == b["revs"], "%dj s%d: mismo orden de state_changed" % [np, sd])


func test_same_result_with_human_and_auto_pass() -> void:
	for mode: String in ["all", "affecting"]:
		for sd: int in [1, 2]:
			var a: Dictionary = _trace(_session(4, 1, sd, true, mode), 300)
			var b: Dictionary = _trace(_session(4, 1, sd, false, mode), 300)
			assert_eq(a["applied"], b["applied"], "%s s%d: mismas acciones" % [mode, sd])
			assert_true(a["state"] == b["state"], "%s s%d: mismo estado" % [mode, sd])
			assert_true(a["history"] == b["history"], "%s s%d: mismo historial" % [mode, sd])
			assert_true(a["revs"] == b["revs"], "%s s%d: mismo orden de state_changed" % [mode, sd])


func test_stale_validation_is_not_reused() -> void:
	# Si entre la validacion y _apply el estado deja de ser el mismo objeto, se recalcula.
	var ls: LocalSession = _session(3, 0, 5, true)
	var a: Dictionary = ls._bot_action(ls.next_bot())
	assert_false(ls._validated.is_empty(), "queda validada")
	ls.state = ls.state.duplicate(true)
	var c0: int = ls.reduce_calls
	var rev0: int = ls.get_rev()
	ls._enqueue(a, "bot")
	assert_eq(ls.reduce_calls - c0, 1, "se recalcula en _apply")
	assert_eq(ls.get_rev(), rev0 + 1, "y se aplica igualmente")
	assert_true(ls._validated.is_empty(), "la validacion se consume")
