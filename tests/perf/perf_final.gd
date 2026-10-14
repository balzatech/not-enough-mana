extends SceneTree
## Benchmark final de la mesa (V2-34). NO es un test GUT. Necesita GPU/pantalla (no headless).
##   godot --path . -s tests/perf/perf_final.gd -- <jugadores> <ancho> <alto> <modo> <segundos> [semilla]
## modo:
##   real   retardo de bot por defecto (600-900 ms); fotogramas + desglose de lo que se hace en el fotograma con acción
##   stress retardo 0 (una acción de bot por fotograma)
##   ui     coste de abrir la ficha, el zoom, la ayuda y la pantalla de fin (ms de construcción + fotograma siguiente)
##   leak   3 partidas completas seguidas en la misma sesión; nodos/objetos/memoria tras liberar la mesa
## Salida: una línea "PERF {json}". Agregar con tests/perf/aggregate_final.py. Orquesta: tests/perf/run_v02_final.sh.
## Mismo método que perf_table.gd (V2-20): SubViewport 1080x1920 (o 720x1280 con size_2d_override 1080x1920),
## vsync desactivado, p1 humano jugado por el script con Bot.choose_action, resto bots.

const BASE: Vector2i = Vector2i(1080, 1920)
const STEPS: Array[String] = ["menu", "log", "players", "center", "actions", "hand", "notices_prompts_game_over"]

var _active: bool = false
var _actions: int = 0
var _sd: int = 11
var _np: int = 3
var _t: TableScreen
var _ls: LocalSession
var _ids: Array[String] = []
var _acc: Dictionary = {}
var _go_ms: float = -1.0
var _go_lap: float = -1.0
var _snap: Dictionary = {}
var _keep: Array = []
## [tipo, ms] de cada FeedbackLayer.play (en orden): detecta el coste del primer uso de cada tipo.
var _layer_log: Array = []


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


# ---------------------------------------------------------------- utilidades

func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b: Array = a.duplicate()
	b.sort()
	return float(b[mini(b.size() - 1, int(floor(p * b.size())))])


func _mean(a: Array) -> float:
	var s: float = 0.0
	for x: Variant in a:
		s += float(x)
	return s / maxf(1.0, a.size())


func _col(rows: Array, k: String) -> Array:
	var o: Array = []
	for r: Variant in rows:
		o.append(float((r as Dictionary).get(k, 0.0)))
	return o


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


func _mon(m: int) -> float:
	return Performance.get_monitor(m)


func _mb(m: int) -> float:
	return Performance.get_monitor(m) / 1048576.0


func _collect(path: String, into: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".webp") or f.ends_with(".png"):
			into.append(path.path_join(f))
	for sub: String in d.get_directories():
		_collect(path.path_join(sub), into)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


# ---------------------------------------------------------------- montaje

func _mk_setup(np: int) -> Dictionary:
	var names: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Eva", "Fede"]
	var players: Array = []
	for i: int in np:
		players.append({"name": names[i], "age": 30 + i * 5, "birth_month": i + 2, "is_bot": i >= 1})
	return {"players": players, "config": {"potion_limit_enabled": true, "potion_limit": 10,
		"potion_mana": 3, "include_curse_of_rules": true, "reaction_timeout_local_ms": 15000, "mode": "local"}}


## Crea sesión + mesa dentro de `vp`, con envoltorios cronometrados en las 3 conexiones del fotograma con acción.
func _make_table(vp: SubViewport, stress: bool, out: Dictionary) -> void:
	_ls = LocalSession.create(_mk_setup(_np), _sd)
	if stress:
		_ls.bot_delay_min_ms = 0
		_ls.bot_delay_max_ms = 0
	var t0: int = Time.get_ticks_usec()
	_t = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	_t.demo_when_empty = false
	vp.add_child(_t)
	out["instantiate_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	_t.bind_session(_ls)
	out["bind_first_refresh_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	# Sustituye las conexiones de TableSync, bus y capa por envoltorios que miden (mismo orden).
	var fb: TableFeedback = _t.feedback()
	_ls.state_changed.disconnect(_t.ctx.sync.on_state_changed)
	_ls.state_changed.connect(_timed_sync)
	_ls.state_changed.disconnect(fb.bus.ingest)
	_ls.state_changed.connect(_timed_bus)
	fb.bus.feedback_started.disconnect(fb.layer.play)
	fb.bus.feedback_started.connect(_timed_layer)
	_ls.state_changed.connect(func(_a: Variant = null, _b: Variant = null) -> void: _active = true)
	# Callback del temporizador de bots cronometrado (decisión + reduce + cadena de señales).
	var bt: Timer = _ls._bot_timer
	bt.timeout.disconnect(_ls._on_bot_timer)
	bt.timeout.connect(_timed_bot)
	_ids = _ls.get_local_player_ids()
	_t.profile_refresh = true
	_zero_acc()


func _zero_acc() -> void:
	_acc = {"sync": 0.0, "bus": 0.0, "layer": 0.0, "submit": 0.0, "decide": 0.0, "botcb": 0.0}


func _timed_sync(rev: int, events: Array) -> void:
	var shown_before: bool = _t.is_game_over_shown()
	var lap_before: float = float(_t.refresh_profile.get("notices_prompts_game_over", 0.0))
	var t0: int = Time.get_ticks_usec()
	_t.ctx.sync.on_state_changed(rev, events)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_acc["sync"] += ms
	if not shown_before and _t.is_game_over_shown() and _go_ms < 0.0:
		_go_ms = ms
		_go_lap = float(_t.refresh_profile.get("notices_prompts_game_over", 0.0)) - lap_before


func _timed_bot() -> void:
	var t0: int = Time.get_ticks_usec()
	_ls.step_bot()
	_acc["botcb"] += (Time.get_ticks_usec() - t0) / 1000.0


func _timed_bus(rev: int, events: Array) -> void:
	var t0: int = Time.get_ticks_usec()
	_t.feedback().bus.ingest(rev, events)
	_acc["bus"] += (Time.get_ticks_usec() - t0) / 1000.0


func _timed_layer(item: Dictionary) -> void:
	var t0: int = Time.get_ticks_usec()
	_t.feedback().layer.play(item)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_acc["layer"] += ms
	_layer_log.append([String(item.get("kind", "")), snappedf(ms, 0.001)])


## Una acción del humano (script). Devuelve false si no hay decisión o acción.
func _human_step() -> bool:
	if String(_ls.state["status"]) != Types.STATUS_PLAYING:
		return false
	var d: String = Decision.local_decider(_ls.state, _ids)
	if d == "":
		return false
	var t0: int = Time.get_ticks_usec()
	var a: Dictionary = Bot.choose_action(_ls.get_view_for(d), d, _sd + _actions, 0)["action"]
	_acc["decide"] += (Time.get_ticks_usec() - t0) / 1000.0
	if a.is_empty():
		return false
	var ts: int = Time.get_ticks_usec()
	_ls.submit_action(a)
	_acc["submit"] += (Time.get_ticks_usec() - ts) / 1000.0
	_actions += 1
	if _actions == 25 and _snap.is_empty():
		_snap = _ls.state.duplicate(true)
	return true


func _new_vp(w: int, h: int) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	return vp


func _load_textures(out: Dictionary) -> void:
	for i: int in 5:
		await process_frame
	out["tex_mem_before_mb"] = _mb(Performance.RENDER_TEXTURE_MEM_USED)
	out["static_mem_before_mb"] = _mb(Performance.MEMORY_STATIC)
	var files: Array[String] = []
	_collect("res://assets", files)
	for f: String in files:
		_keep.append(load(f))
	out["textures_loaded"] = _keep.size()


# ---------------------------------------------------------------- principal

func _run(args: PackedStringArray) -> void:
	_np = int(args[0]) if args.size() > 0 else 3
	var w: int = int(args[1]) if args.size() > 1 else 1080
	var h: int = int(args[2]) if args.size() > 2 else 1920
	var mode: String = args[3] if args.size() > 3 else "real"
	var secs: float = float(args[4]) if args.size() > 4 else 20.0
	_sd = int(args[5]) if args.size() > 5 else 11
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var out: Dictionary = {"players": _np, "w": w, "h": h, "mode": mode, "seed": _sd}
	await _load_textures(out)
	var vp: SubViewport = _new_vp(w, h)
	await _frames(3)
	out["tex_mem_after_load_mb"] = _mb(Performance.RENDER_TEXTURE_MEM_USED)
	out["static_mem_after_load_mb"] = _mb(Performance.MEMORY_STATIC)
	var nodes0: int = int(_mon(Performance.OBJECT_NODE_COUNT))
	out["nodes_baseline"] = nodes0
	match mode:
		"leak":
			await _mode_leak(vp, out, secs)
		"ui":
			await _mode_ui(vp, out, secs)
		_:
			await _mode_frames(vp, out, secs, mode == "stress", nodes0)
	print("PERF " + JSON.stringify(out))
	quit()


# ---------------------------------------------------------------- modo real / stress

func _mode_frames(vp: SubViewport, out: Dictionary, secs: float, stress: bool, nodes0: int) -> void:
	_make_table(vp, stress, out)
	await _frames(30)
	_t.refresh_profile.clear()
	_t.refresh_count = 0
	out["table_nodes"] = _count(_t)
	out["nodes_total_delta"] = int(_mon(Performance.OBJECT_NODE_COUNT)) - nodes0
	out["nodes_total"] = int(_mon(Performance.OBJECT_NODE_COUNT))
	var all: Array = []
	var act: Array = []
	var anim: Array = []
	var rows: Array = []
	var gcpu: Array = []
	var ggpu: Array = []
	var draw: Array = []
	var series: Array = []
	var prev: Dictionary = {}
	var rc_prev: int = 0
	var vrid: RID = vp.get_viewport_rid()
	var fb: TableFeedback = _t.feedback()
	var start: int = Time.get_ticks_usec()
	var last: int = start
	while float(Time.get_ticks_usec() - start) / 1e6 < secs:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = (now - last) / 1000.0
		last = now
		all.append(dt)
		var rcpu: float = RenderingServer.viewport_get_measured_render_time_cpu(vrid)
		var rgpu: float = RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		gcpu.append(rcpu)
		ggpu.append(rgpu)
		draw.append(_mon(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if _active:
			var row: Dictionary = {"dt": dt, "render_cpu": rcpu, "render_gpu": rgpu,
				"refresh_calls": _t.refresh_count - rc_prev, "human": 1.0 if _acc["submit"] > 0.0 else 0.0}
			rc_prev = _t.refresh_count
			for k: String in _acc:
				row[k] = _acc[k]
			var prof_sum: float = 0.0
			for s: String in STEPS:
				var cur: float = float(_t.refresh_profile.get(s, 0.0))
				row["r_" + s] = cur - float(prev.get(s, 0.0))
				prof_sum += float(row["r_" + s])
				prev[s] = cur
			row["refresh"] = prof_sum
			# rest = lo que no es sync/bus/capa ni la decision del script: motor (reduce, bot), layout diferido, dibujo.
			row["engine_human"] = maxf(0.0, float(row["submit"]) - float(row["sync"]) - float(row["bus"]))
			row["engine_bot"] = maxf(0.0, float(row["botcb"]) - float(row["sync"]) - float(row["bus"]))
			row["rest"] = dt - float(row["sync"]) - float(row["bus"]) - float(row["layer"]) - float(row["decide"]) \
				- float(row["engine_human"]) - float(row["engine_bot"])
			rows.append(row)
			act.append(dt)
			_active = false
			if rows.size() % 10 == 0:
				series.append([rows.size(), int(_mon(Performance.OBJECT_NODE_COUNT))])
		elif fb.bus.pending_count() > 0 or fb.layer.active_count() > 0:
			anim.append(dt)
		_zero_acc()
		if String(_ls.state["status"]) != Types.STATUS_PLAYING:
			break
		_human_step()
	out["frames"] = all.size()
	out["frame_ms_mean"] = _mean(all)
	out["frame_ms_p50"] = _pct(all, 0.5)
	out["frame_ms_p95"] = _pct(all, 0.95)
	out["frame_ms_max"] = _pct(all, 1.0)
	out["active_frames"] = act.size()
	out["active_ms_p50"] = _pct(act, 0.5)
	out["active_ms_p95"] = _pct(act, 0.95)
	out["active_ms_max"] = _pct(act, 1.0)
	out["active_ms_mean"] = _mean(act)
	out["anim_frames"] = anim.size()
	out["anim_ms_p50"] = _pct(anim, 0.5)
	out["anim_ms_p95"] = _pct(anim, 0.95)
	out["anim_ms_max"] = _pct(anim, 1.0)
	out["anim_ms_p99"] = _pct(anim, 0.99)
	out["anim_over16_frames"] = anim.filter(func(x: Variant) -> bool: return float(x) > 16.0).size()
	out["frames_over16"] = all.filter(func(x: Variant) -> bool: return float(x) > 16.0).size()
	out["active_over16_frames"] = act.filter(func(x: Variant) -> bool: return float(x) > 16.0).size()
	# Fotograma con accion sin la decision del humano (la toma el script con Bot.choose_action; un humano real no la paga en el hilo).
	var nd: Array = []
	for r: Variant in rows:
		nd.append(float((r as Dictionary)["dt"]) - float((r as Dictionary)["decide"]))
	out["active_nodecide_p50"] = _pct(nd, 0.5)
	out["active_nodecide_p95"] = _pct(nd, 0.95)
	out["active_nodecide_max"] = _pct(nd, 1.0)
	out["active_nodecide_over16"] = nd.filter(func(x: Variant) -> bool: return float(x) > 16.0).size()
	out["render_cpu_ms_p50"] = _pct(gcpu, 0.5)
	out["render_gpu_ms_p50"] = _pct(ggpu, 0.5)
	out["render_gpu_ms_p95"] = _pct(ggpu, 0.95)
	out["draw_calls_p50"] = _pct(draw, 0.5)
	out["game_over"] = String(_ls.state["status"]) != Types.STATUS_PLAYING
	out["rev"] = int(_ls.state.get("rev", 0))
	out["actions"] = _actions
	out["nodes_end"] = int(_mon(Performance.OBJECT_NODE_COUNT))
	out["table_nodes_end"] = _count(_t)
	out["nodes_series"] = series
	out["refresh_count"] = _t.refresh_count
	out["gameover_build_ms"] = _go_ms
	out["gameover_refresh_lap_ms"] = _go_lap
	# Desglose del fotograma con acción: media de todos y media del 5 % peor (cola, la que define p95).
	var p95: float = _pct(act, 0.95)
	var tail: Array = []
	for r: Variant in rows:
		if float((r as Dictionary)["dt"]) >= p95:
			tail.append(r)
	var keys: Array[String] = ["dt", "sync", "bus", "layer", "decide", "submit", "rest", "refresh", "refresh_calls",
		"render_cpu", "render_gpu", "human", "engine_human", "engine_bot", "botcb"]
	for s: String in STEPS:
		keys.append("r_" + s)
	var rows_h: Array = rows.filter(func(r: Variant) -> bool: return float((r as Dictionary)["human"]) > 0.0)
	var rows_b: Array = rows.filter(func(r: Variant) -> bool: return float((r as Dictionary)["human"]) == 0.0)
	out["layer_calls"] = _layer_log.size()
	out["layer_first10_ms"] = _layer_log.slice(0, 10).map(func(e: Array) -> float: return float(e[1]))
	var late: Array = _layer_log.slice(10).map(func(e: Array) -> float: return float(e[1]))
	out["layer_after10_mean_ms"] = _mean(late)
	out["layer_after10_max_ms"] = _pct(late, 1.0)
	var top: Array = rows.duplicate()
	top.sort_custom(func(a: Variant, b: Variant) -> bool: return float((a as Dictionary)["dt"]) > float((b as Dictionary)["dt"]))
	var top_out: Array = []
	for r: Variant in top.slice(0, 8):
		var rd: Dictionary = {}
		for k: String in ["dt", "sync", "layer", "decide", "engine_human", "engine_bot", "rest", "refresh", "human"]:
			rd[k] = snappedf(float((r as Dictionary)[k]), 0.01)
		top_out.append(rd)
	out["top_rows"] = top_out
	out["tail_n"] = tail.size()
	out["human_frames"] = rows_h.size()
	for k: String in keys:
		out["m_" + k] = _mean(_col(rows, k))
		out["tail_" + k] = _mean(_col(tail, k))
		out["hum_" + k] = _mean(_col(rows_h, k))
		out["bot_" + k] = _mean(_col(rows_b, k))
	out["hum_dt_p95"] = _pct(_col(rows_h, "dt"), 0.95)
	out["bot_dt_p95"] = _pct(_col(rows_b, "dt"), 0.95)
	out["human_submit_ms_mean"] = _mean(_col(rows_h, "submit"))
	# Refresh por llamada, por módulo (media de todas las llamadas del recorrido).
	var rc: float = maxf(1.0, _t.refresh_count)
	var rtot: float = 0.0
	for s: String in STEPS:
		var v: float = float(_t.refresh_profile.get(s, 0.0)) / rc
		out["refresh_call_" + s] = v
		rtot += v
	out["refresh_call_total"] = rtot
	_fixture_bench(out)
	await process_frame
	out["tex_mem_end_mb"] = _mb(Performance.RENDER_TEXTURE_MEM_USED)
	out["static_mem_end_mb"] = _mb(Performance.MEMORY_STATIC)
	out["vram_mb"] = _mb(Performance.RENDER_VIDEO_MEM_USED)


## Microbenchmarks sobre un estado FIJO (la partida tras 25 acciones del humano; misma semilla = mismo estado).
func _fixture_bench(out: Dictionary) -> void:
	var st: Dictionary = _snap if not _snap.is_empty() else _ls.state
	out["fixture_actions"] = 25 if not _snap.is_empty() else _actions
	var pid: String = Decision.local_decider(st, _ids)
	if pid == "":
		pid = String((st["turn"] as Dictionary)["current"])
	var view: Dictionary = Types.view_for(st, pid)
	var act1: Dictionary = Bot.choose_action(view, pid, 7, 0)["action"]
	if act1.is_empty():
		act1 = Types.make_action_drink_potion(pid)
	var reps: int = 200
	var opts: ActionOptions = ActionOptions.build(view, pid)
	out["fx_reduce_ms"] = _bench(func() -> void: Game.reduce(st, act1), reps)
	out["fx_legal_actions_ms"] = _bench(func() -> void: Game.legal_actions(view, pid), reps)
	out["fx_bot_decision_ms"] = _bench(func() -> void: Bot.choose_action(st, pid, 7, 0), reps)
	out["fx_view_for_ms"] = _bench(func() -> void: Types.view_for(st, pid), reps)
	out["fx_validate_state_ms"] = _bench(func() -> void: Types.validate_state(st), 50)
	out["fx_action_options_ms"] = _bench(func() -> void: ActionOptions.build(view, pid), reps)
	out["fx_card_info_for_hand_ms"] = _bench(func() -> void: CardInfo.for_hand(view, pid, opts), reps)
	var entries: Array = view.get("log", []) as Array
	out["fx_log_entries"] = entries.size()
	out["fx_mapper_all_log_ms"] = _bench(func() -> void:
		for e: Variant in entries:
			FeedbackMapper.map_entry(e as Dictionary, 1), 20)
	var tail: Array = entries.slice(maxi(0, entries.size() - 6))
	var bus: PresentationBus = PresentationBus.new()
	out["fx_bus_ingest_6_entries_ms"] = _bench(func() -> void:
		bus.bind(_ls, Callable(), {})
		bus.ingest(1, tail), 50)
	bus.free()
	out["fx_refresh_unchanged_ms"] = _bench(func() -> void: _t.refresh(), 30)


# ---------------------------------------------------------------- modo ui

func _mode_ui(vp: SubViewport, out: Dictionary, _secs: float) -> void:
	_make_table(vp, true, out)
	await _frames(30)
	_t.profile_refresh = false
	# Avanza hasta tener una mano jugada (25 acciones) con el humano activo.
	var guard: int = 0
	while _actions < 25 and guard < 4000:
		await process_frame
		_human_step()
		guard += 1
	_ls.auto_run_bots = false
	_ls.cancel_bot()
	await _frames(20)
	# Frame de reposo: mediana de 40 fotogramas.
	var idle: Array = []
	var last: int = Time.get_ticks_usec()
	for i: int in 40:
		await process_frame
		var n: int = Time.get_ticks_usec()
		idle.append((n - last) / 1000.0)
		last = n
	var idle_p50: float = _pct(idle, 0.5)
	out["idle_frame_ms_p50"] = idle_p50
	var pid: String = _t.viewer_id
	var view: Dictionary = _t.view
	var me: Dictionary = Types.get_player(view, pid)
	var hand: Array = me.get("hand", []) as Array
	out["hand_size"] = hand.size()
	# Cartas variadas (12 ids repartidos por el catálogo) para que la ficha y el zoom no midan siempre la misma.
	var ids_all: Array = CardCatalog.all_defs().keys()
	ids_all.sort()
	hand = []
	for i: int in 12:
		hand.append({"iid": 9000 + i, "card_id": String(ids_all[(i * 13) % ids_all.size()])})
	var info: CardInfo = _t.ctx.hand.info
	var opts: ActionOptions = _t.ctx.opts
	var reps: int = 20
	# --- Ficha: show_info (+ layout/dibujo del fotograma siguiente), luego clear.
	var call_ms: Array = []
	var frame_ms: Array = []
	var nodes_f0: int = int(_mon(Performance.OBJECT_NODE_COUNT))
	for i: int in reps:
		var c: Dictionary = hand[i % hand.size()]
		var ev: Dictionary = CardInfo.evaluate(view, pid, opts, c)
		var t0: int = Time.get_ticks_usec()
		info.show_info(ev, c)
		var t1: int = Time.get_ticks_usec()
		await process_frame
		var t2: int = Time.get_ticks_usec()
		call_ms.append((t1 - t0) / 1000.0)
		frame_ms.append((t2 - t1) / 1000.0)
		info.clear()
		await process_frame
	out["ficha_first_frame_ms"] = float(frame_ms[0])
	out["ficha_call_ms"] = _mean(call_ms)
	out["ficha_next_frame_ms"] = _mean(frame_ms)
	out["ficha_next_frame_p95_ms"] = _pct(frame_ms, 0.95)
	out["ficha_nodes_delta"] = int(_mon(Performance.OBJECT_NODE_COUNT)) - nodes_f0
	# --- Zoom: show_card (construye CardView grande + resumen) + fotograma siguiente.
	call_ms = []
	frame_ms = []
	var zoom_nodes: int = 0
	var dz: Array = []
	for i: int in reps:
		var c: Dictionary = hand[i % hand.size()]
		var def: Dictionary = CardCatalog.get_def(String(c.get("card_id", "")))
		var n0: int = int(_mon(Performance.OBJECT_NODE_COUNT))
		var t0: int = Time.get_ticks_usec()
		_t.show_zoom(c, def)
		var t1: int = Time.get_ticks_usec()
		await process_frame
		var t2: int = Time.get_ticks_usec()
		call_ms.append((t1 - t0) / 1000.0)
		frame_ms.append((t2 - t1) / 1000.0)
		zoom_nodes = int(_mon(Performance.OBJECT_NODE_COUNT)) - n0
		_t._zoom.visible = false
		await process_frame
		dz.append(int(_mon(Performance.OBJECT_NODE_COUNT)) - n0)
	out["zoom_first_frame_ms"] = float(frame_ms[0])
	out["zoom_call_ms"] = _mean(call_ms)
	out["zoom_next_frame_ms"] = _mean(frame_ms)
	out["zoom_next_frame_p95_ms"] = _pct(frame_ms, 0.95)
	out["zoom_nodes_delta"] = zoom_nodes
	# --- Ayuda: open_help (HelpScreen completa con 8 secciones) + fotograma(s) + cerrar.
	call_ms = []
	frame_ms = []
	var close_ms: Array = []
	var help_nodes: int = 0
	for i: int in 10:
		var n0: int = int(_mon(Performance.OBJECT_NODE_COUNT))
		var t0: int = Time.get_ticks_usec()
		_t.ctx.menu.open_help()
		var t1: int = Time.get_ticks_usec()
		await process_frame
		var t2: int = Time.get_ticks_usec()
		await process_frame
		var t3: int = Time.get_ticks_usec()
		call_ms.append((t1 - t0) / 1000.0)
		frame_ms.append((t2 - t1) / 1000.0 + (t3 - t2) / 1000.0)
		help_nodes = int(_mon(Performance.OBJECT_NODE_COUNT)) - n0
		var c0: int = Time.get_ticks_usec()
		_t.ctx.menu.close_help()
		await process_frame
		close_ms.append((Time.get_ticks_usec() - c0) / 1000.0)
	out["help_first_call_ms"] = float(call_ms[0])
	out["help_first_frames_ms"] = float(frame_ms[0])
	out["help_call_ms"] = _mean(call_ms)
	out["help_next_frames_ms"] = _mean(frame_ms)
	out["help_next_frames_max_ms"] = _pct(frame_ms, 1.0)
	out["help_close_ms"] = _mean(close_ms)
	out["help_nodes_delta"] = help_nodes
	# --- Fin de partida: jugar hasta el final y medir la construcción (sync + refresh) y los fotogramas.
	_t.profile_refresh = true
	_t.refresh_profile.clear()
	var n_before_over: int = int(_mon(Performance.OBJECT_NODE_COUNT))
	_ls.auto_run_bots = true
	_ls._schedule()
	var go_frames: Array = []
	var t_start: int = Time.get_ticks_usec()
	var over_frame: float = -1.0
	last = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - t_start) / 1e6 < 90.0:
		await process_frame
		var n: int = Time.get_ticks_usec()
		var dt: float = (n - last) / 1000.0
		last = n
		if _t.is_game_over_shown():
			over_frame = dt if over_frame < 0.0 else over_frame
			go_frames.append(dt)
			if go_frames.size() >= 5:
				break
		_human_step()
	out["gameover_reached"] = _t.is_game_over_shown()
	out["gameover_build_ms"] = _go_ms
	out["gameover_refresh_lap_ms"] = _go_lap
	out["gameover_frame_ms"] = over_frame
	out["gameover_nodes_delta"] = int(_mon(Performance.OBJECT_NODE_COUNT)) - n_before_over
	# Reabrir resultado: hide + show.
	var go: TableGameOver = _t.ctx.game_over
	var ro: Array = []
	var rf: Array = []
	if go.overlay != null:
		for i: int in 10:
			go.hide_result()
			await process_frame
			var t0: int = Time.get_ticks_usec()
			go.show_result()
			var t1: int = Time.get_ticks_usec()
			await process_frame
			ro.append((t1 - t0) / 1000.0)
			rf.append((Time.get_ticks_usec() - t1) / 1000.0)
		out["gameover_reopen_call_ms"] = _mean(ro)
		out["gameover_reopen_frame_ms"] = _mean(rf)
		# Resumen en solitario: MatchSummary.build + GameOverSummary.show_summary.
		var fv: Dictionary = _t.view
		var lids: Array[String] = _t.ctx.local_ids
		out["matchsummary_build_ms"] = _bench(func() -> void: MatchSummary.build(fv, lids), 50)
		var sm: Dictionary = MatchSummary.build(fv, lids)
		out["gameoversummary_show_ms"] = _bench(func() -> void: go.summary_view.show_summary(sm), 20)
	# Mesa nueva enlazada a la sesión ya terminada: construcción completa del fin (bind + refresh + check()).
	var t_bind0: int = Time.get_ticks_usec()
	var t2: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t2.demo_when_empty = false
	vp.add_child(t2)
	var tb: int = Time.get_ticks_usec()
	t2.bind_session(_ls)
	out["bind_finished_session_ms"] = (Time.get_ticks_usec() - tb) / 1000.0
	out["table2_instantiate_ms"] = (tb - t_bind0) / 1000.0
	out["gameover_shown_on_new_table"] = t2.is_game_over_shown()


# ---------------------------------------------------------------- modo leak

func _mode_leak(vp: SubViewport, out: Dictionary, secs: float) -> void:
	var games: Array = []
	var seed0: int = _sd
	var base: Dictionary = _snapshot_objects()
	out["leak_baseline"] = base
	var n_games: int = int(OS.get_environment("NEM_LEAK_GAMES")) if OS.get_environment("NEM_LEAK_GAMES") != "" else 3
	for g: int in n_games:
		_actions = 0
		_snap = {}
		_sd = seed0 + g
		_go_ms = -1.0
		_go_lap = -1.0
		var rec: Dictionary = {}
		_make_table(vp, true, rec)
		await _frames(5)
		var t_start: int = Time.get_ticks_usec()
		var frames: int = 0
		var peak_nodes: int = 0
		while float(Time.get_ticks_usec() - t_start) / 1e6 < secs:
			await process_frame
			frames += 1
			peak_nodes = maxi(peak_nodes, int(_mon(Performance.OBJECT_NODE_COUNT)))
			if String(_ls.state["status"]) != Types.STATUS_PLAYING:
				break
			_human_step()
		await _frames(3)
		rec["finished"] = String(_ls.state["status"]) != Types.STATUS_PLAYING
		rec["actions"] = _actions
		rec["rev"] = int(_ls.state.get("rev", 0))
		rec["frames"] = frames
		rec["seconds"] = float(Time.get_ticks_usec() - t_start) / 1e6
		rec["peak_nodes"] = peak_nodes
		rec["game_over_shown"] = _t.is_game_over_shown()
		rec["at_end"] = _snapshot_objects()
		rec["table_nodes_at_end"] = _count(_t)
		_t.queue_free()
		_t = null
		_ls = null
		await _frames(5)
		rec["after_free"] = _snapshot_objects()
		games.append(rec)
	out["games"] = games
	var last_after: Dictionary = (games[games.size() - 1] as Dictionary)["after_free"]
	for k: String in base:
		out["leak_delta_" + k] = float(last_after[k]) - float(base[k])
	out["leak_nodes_after_g1"] = (games[0] as Dictionary)["after_free"]["nodes"]
	out["leak_nodes_after_g3"] = (games[mini(2, games.size() - 1)] as Dictionary)["after_free"]["nodes"]
	out["leak_games"] = games.size()


func _snapshot_objects() -> Dictionary:
	return {"nodes": int(_mon(Performance.OBJECT_NODE_COUNT)), "orphans": int(_mon(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(_mon(Performance.OBJECT_COUNT)), "resources": int(_mon(Performance.OBJECT_RESOURCE_COUNT)),
		"static_mb": _mb(Performance.MEMORY_STATIC), "tex_mb": _mb(Performance.RENDER_TEXTURE_MEM_USED)}
