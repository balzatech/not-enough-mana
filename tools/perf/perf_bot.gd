extends SceneTree
## Coste por accion de bot sobre partidas completas (V2-34): decision (Bot.choose_action), validacion (Game.reduce) y
## paso completo de LocalSession.step_bot (decision + 2 reduce + vista/validaciones + senales sin UI).
## No necesita GPU. godot --headless --path . -s tools/perf/perf_bot.gd -- <jugadores> <semillas> [semilla_inicial]
## Salida: "PERF {json}" (mode="bot").

func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b: Array = a.duplicate()
	b.sort()
	return float(b[mini(b.size() - 1, int(floor(p * b.size())))])


func _run(args: PackedStringArray) -> void:
	var np: int = int(args[0]) if args.size() > 0 else 3
	var n_seeds: int = int(args[1]) if args.size() > 1 else 5
	var s0: int = int(args[2]) if args.size() > 2 else 1
	var names: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Eva", "Fede"]
	var choose: Array = []
	var reduce_t: Array = []
	var step: Array = []
	var by_kind: Dictionary = {}
	var total_actions: int = 0
	for sd: int in range(s0, s0 + n_seeds):
		var players: Array = []
		for i: int in np:
			players.append({"name": names[i], "age": 30 + i * 5, "birth_month": i + 2, "is_bot": true})
		var setup: Dictionary = {"players": players, "config": {"potion_limit_enabled": true, "potion_limit": 10,
			"potion_mana": 3, "include_curse_of_rules": true, "reaction_timeout_local_ms": 15000, "mode": "local"}}
		var ls: LocalSession = LocalSession.create(setup, sd)
		ls.auto_run_bots = false
		root.add_child(ls)
		var guard: int = 0
		while String(ls.state["status"]) == Types.STATUS_PLAYING and guard < 2000:
			guard += 1
			var pid: String = ls.next_bot()
			if pid == "":
				break
			var t0: int = Time.get_ticks_usec()
			var res: Dictionary = Bot.choose_action(ls.state, pid, 12345 + guard, 0)
			var t1: int = Time.get_ticks_usec()
			var a: Dictionary = res.get("action", {}) as Dictionary
			if not a.is_empty():
				Game.reduce(ls.state, a)
			var t2: int = Time.get_ticks_usec()
			var ok: bool = ls.step_bot()
			var t3: int = Time.get_ticks_usec()
			if not ok:
				break
			var kind: String = String(a.get("type", "?"))
			choose.append((t1 - t0) / 1000.0)
			reduce_t.append((t2 - t1) / 1000.0)
			step.append((t3 - t2) / 1000.0)
			if not by_kind.has(kind):
				by_kind[kind] = []
			(by_kind[kind] as Array).append((t1 - t0) / 1000.0)
			total_actions += 1
		ls.queue_free()
		await process_frame
	var kinds: Dictionary = {}
	for k: String in by_kind:
		var arr: Array = by_kind[k]
		kinds[k] = {"n": arr.size(), "p50": snappedf(_pct(arr, 0.5), 0.001), "p95": snappedf(_pct(arr, 0.95), 0.001), "max": snappedf(_pct(arr, 1.0), 0.001)}
	var out: Dictionary = {"mode": "bot", "players": np, "w": 0, "seeds": n_seeds, "actions": total_actions,
		"choose_p50": _pct(choose, 0.5), "choose_p95": _pct(choose, 0.95), "choose_max": _pct(choose, 1.0),
		"choose_over8": choose.filter(func(x: Variant) -> bool: return float(x) > 8.0).size(),
		"reduce_p50": _pct(reduce_t, 0.5), "reduce_p95": _pct(reduce_t, 0.95), "reduce_max": _pct(reduce_t, 1.0),
		"step_p50": _pct(step, 0.5), "step_p95": _pct(step, 0.95), "step_max": _pct(step, 1.0), "kinds": kinds}
	print("PERF " + JSON.stringify(out))
	quit()
