extends SceneTree
## Benchmark de la mesa (V2-20). NO es un test GUT (no empieza por test_ y no
## está en una carpeta que GUT incluya con prefijo test_). Necesita GPU/pantalla.
##   godot --path . -s tests/perf/perf_table.gd -- <jugadores> <ancho> <alto> <modo> <segundos> [semilla]
## modo: real (retardo de bot por defecto 600-900 ms) | stress (retardo 0: una acción de bot por fotograma)
## Salida: una línea "PERF {json}". Agregar con tests/perf/run_v02_base.sh.
## La partida: p1 humano (lo juega el script con Bot.choose_action) + bots.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)

var _active: bool = false
var _actions: int = 0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _pct(a: Array, p: float) -> float:
	var b: Array = a.duplicate()
	b.sort()
	if b.is_empty():
		return 0.0
	return float(b[mini(b.size() - 1, int(floor(p * b.size())))])


func _mean(a: Array) -> float:
	var s: float = 0.0
	for x: Variant in a:
		s += float(x)
	return s / maxf(1.0, a.size())


func _count(n: Node) -> int:
	var c: int = 1
	for ch: Node in n.get_children():
		c += _count(ch)
	return c


func _bench(f: Callable, n: int) -> float:
	var t0: int = Time.get_ticks_usec()
	for i: int in n:
		f.call()
	return float(Time.get_ticks_usec() - t0) / 1000.0 / n


func _run(args: PackedStringArray) -> void:
	var np: int = int(args[0]) if args.size() > 0 else 3
	var w: int = int(args[1]) if args.size() > 1 else 1080
	var h: int = int(args[2]) if args.size() > 2 else 1920
	var mode: String = args[3] if args.size() > 3 else "real"
	var secs: float = float(args[4]) if args.size() > 4 else 20.0
	var sd: int = int(args[5]) if args.size() > 5 else 11
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var out: Dictionary = {"players": np, "w": w, "h": h, "mode": mode, "seed": sd}
	# Memoria: antes / después de cargar las texturas de cartas.
	for i: int in 5:
		await process_frame
	out["tex_mem_before_mb"] = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	out["static_mem_before_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var keep: Array = []
	var files: Array[String] = []
	_collect("res://assets", files)
	for f: String in files:
		keep.append(load(f))
	out["textures_loaded"] = keep.size()
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	for i: int in 3:
		await process_frame
	out["tex_mem_after_load_mb"] = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	out["static_mem_after_load_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var nodes0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	var names: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Eva", "Fede"]
	var players: Array = []
	for i: int in np:
		players.append({"name": names[i], "age": 30 + i * 5, "birth_month": i + 2, "is_bot": i >= 1})
	var setup: Dictionary = {"players": players, "config": {"potion_limit_enabled": true, "potion_limit": 10,
		"potion_mana": 3, "include_curse_of_rules": true, "reaction_timeout_local_ms": 15000, "mode": "local"}}
	var ls: LocalSession = LocalSession.create(setup, sd)
	if mode == "stress":
		ls.bot_delay_min_ms = 0
		ls.bot_delay_max_ms = 0
	var t0: int = Time.get_ticks_usec()
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	vp.add_child(t)
	out["instantiate_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	t.bind_session(ls)
	out["bind_first_refresh_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	ls.state_changed.connect(func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void: _active = true)
	for i: int in 30:
		await process_frame
	out["table_nodes"] = _count(t)
	out["nodes_total_delta"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nodes0
	out["nodes_total"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# Fotogramas durante la partida (humano jugado por el script).
	var all: Array = []
	var act: Array = []
	var sub: Array = []
	var gcpu: Array = []
	var ggpu: Array = []
	var draw: Array = []
	var start: int = Time.get_ticks_usec()
	var last: int = start
	var ids: Array[String] = ls.get_local_player_ids()
	while float(Time.get_ticks_usec() - start) / 1e6 < secs:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = (now - last) / 1000.0
		last = now
		all.append(dt)
		if _active:
			act.append(dt)
			_active = false
		gcpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid()))
		ggpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()))
		draw.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if String(ls.state["status"]) != Types.STATUS_PLAYING:
			break
		var d: String = Decision.local_decider(ls.state, ids)
		if d != "":
			var a: Dictionary = Bot.choose_action(ls.get_view_for(d), d, sd + _actions, 0)["action"]
			if not a.is_empty():
				var ts: int = Time.get_ticks_usec()
				ls.submit_action(a)
				sub.append((Time.get_ticks_usec() - ts) / 1000.0)
				_actions += 1
	out["frames"] = all.size()
	out["frame_ms_mean"] = _mean(all)
	out["frame_ms_p50"] = _pct(all, 0.5)
	out["frame_ms_p95"] = _pct(all, 0.95)
	out["frame_ms_max"] = _pct(all, 1.0)
	out["active_frames"] = act.size()
	out["active_ms_p50"] = _pct(act, 0.5)
	out["active_ms_p95"] = _pct(act, 0.95)
	out["active_ms_max"] = _pct(act, 1.0)
	out["render_cpu_ms_p50"] = _pct(gcpu, 0.5)
	out["render_gpu_ms_p50"] = _pct(ggpu, 0.5)
	out["render_gpu_ms_p95"] = _pct(ggpu, 0.95)
	out["draw_calls_p50"] = _pct(draw, 0.5)
	out["human_submit_ms_mean"] = _mean(sub)
	out["game_over"] = String(ls.state["status"]) != Types.STATUS_PLAYING
	out["rev"] = int(ls.state.get("rev", 0))

	# Microbenchmarks sobre el estado actual (partida en curso).
	var st: Dictionary = ls.state
	var pid: String = Decision.local_decider(st, ids)
	if pid == "":
		pid = String((st["turn"] as Dictionary)["current"])
	var view: Dictionary = ls.get_view_for(pid)
	var act1: Dictionary = Bot.choose_action(view, pid, 7, 0)["action"]
	if act1.is_empty():
		act1 = Types.make_action_drink_potion(pid)
	var reps: int = 200
	out["refresh_ms"] = _bench(func() -> void: t.refresh(), 30)
	out["reduce_ms"] = _bench(func() -> void: Game.reduce(st, act1), reps)
	out["legal_actions_ms"] = _bench(func() -> void: Game.legal_actions(view, pid), reps)
	out["bot_decision_ms"] = _bench(func() -> void: Bot.choose_action(st, pid, 7, 0), reps)
	out["view_for_ms"] = _bench(func() -> void: Types.view_for(st, pid), reps)
	out["validate_state_ms"] = _bench(func() -> void: Types.validate_state(st), 50)
	await process_frame
	out["tex_mem_end_mb"] = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	out["static_mem_end_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	out["vram_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	print("PERF " + JSON.stringify(out))
	quit()


func _collect(path: String, into: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".webp") or f.ends_with(".png"):
			into.append(path.path_join(f))
	for sub: String in d.get_directories():
		_collect(path.path_join(sub), into)
