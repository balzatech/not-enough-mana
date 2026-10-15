extends SceneTree
## Deriva de OBJECT_COUNT por partida (V2-34): 10 partidas de bots SIN interfaz (solo LocalSession), liberando la sesion
## cada vez. Si crece, la deriva viene del motor/sesion; si no, de la UI. godot --headless --path . -s tools/perf/perf_objects.gd -- 6

func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(args: PackedStringArray) -> void:
	var np: int = int(args[0]) if args.size() > 0 else 3
	var names: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Eva", "Fede"]
	var counts: Array = []
	for i: int in 3:
		await process_frame
	counts.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	for g: int in 10:
		var players: Array = []
		for i: int in np:
			players.append({"name": names[i], "age": 30 + i, "birth_month": i + 2, "is_bot": true})
		var setup: Dictionary = {"players": players, "config": {"potion_limit_enabled": true, "potion_limit": 10,
			"potion_mana": 3, "include_curse_of_rules": true, "reaction_timeout_local_ms": 15000, "mode": "local"}}
		var ls: LocalSession = LocalSession.create(setup, 11 + g)
		ls.auto_run_bots = false
		root.add_child(ls)
		ls.run_bots(2000)
		ls.queue_free()
		for i: int in 3:
			await process_frame
		counts.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	print("OBJECTS np=%d %s" % [np, str(counts)])
	quit()
