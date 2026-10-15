extends GutTest
## V2-22: feedback en la mesa (TableFeedback + FeedbackLayer + refresco incremental).

const H = preload("res://tests/fixtures/engine_helpers.gd")
const GAME_SEED: int = 33
const PANEL_TYPES: Dictionary = {
	Types.LOG_DAMAGE: "damage", Types.LOG_HEAL: "heal", Types.LOG_MANA_CHANGED: "mana",
	Types.LOG_POTION: "potion", Types.LOG_ELIMINATED: "eliminated"}

var _now: int = 0


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func after_each() -> void:
	await wait_process_frames(2)


func _clock() -> int:
	return _now


func _table() -> TableScreen:
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	add_child_autofree(t)
	return t


## p1 humano (o p1..p<humans> en hot-seat) y el resto bots; log sin recorte.
func _session(n: int, humans: int = 1, sd: int = GAME_SEED) -> LocalSession:
	var names: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Eva", "Fede"]
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), names[i], 40 - i * 5, i + 1, i >= humans))
	var s: Dictionary = Game.new_game(players, {"log_limit": 100000, "reaction_timeout_local_ms": 15000}, sd)
	var ls: LocalSession = LocalSession.new()
	ls.auto_run_bots = false
	ls.clock = _clock
	ls.start(s, sd)
	return ls


func _bound(ls: LocalSession) -> TableScreen:
	var t: TableScreen = _table()
	t.bind_session(ls)
	t.feedback().bus.auto_advance = false
	return t


func _item(kind: String, target: String, amount: int, seq: int, extra: Dictionary = {}) -> Dictionary:
	return {"log_seq": seq, "rev": 1, "kind": kind, "lane": FeedbackMapper.lane_for(target),
		"target": target, "actor": target, "amount": amount, "card_id": "", "targets": [],
		"extra": extra, "visible_to": [], "duration_ms": FeedbackMapper.DUR_PANEL_MS}


## Partida real de 4 (p1 humano jugado con el bot): 1 feedback dibujado por
## entrada de log, ninguno perdido, todos con panel, y ninguno dispara refresh().
func test_one_feedback_per_event_on_table() -> void:
	var ls: LocalSession = _session(4)
	var t: TableScreen = _bound(ls)
	await wait_process_frames(2)
	var fb: TableFeedback = t.feedback()
	var base_seq: int = fb.bus.last_seq()
	var ids: Array[String] = ["p1"]
	for i: int in 600:
		if String(ls.state["status"]) != Types.STATUS_PLAYING:
			break
		var d: String = Decision.local_decider(ls.state, ids)
		if d != "":
			var a: Dictionary = Bot.choose_action(ls.get_view_for(d), d, GAME_SEED + i, 0)["action"]
			if a.is_empty():
				break
			ls.submit_action(a)
		elif not ls.step_bot():
			break
		fb.bus.advance(50)
		if i % 40 == 0:
			await wait_process_frames(1)
	var refreshes: int = t.refresh_count
	fb.bus.drain()
	assert_true(fb.bus.is_idle())
	assert_eq(t.refresh_count, refreshes, "el feedback no dispara refresh()")
	# Entradas públicas nuevas por tipo.
	var expected: Dictionary = {}
	var expected_seqs: Array = []
	var cards_played: int = 0
	for e: Variant in ls.state["log"] as Array:
		var entry: Dictionary = e
		if int(entry["log_seq"]) <= base_seq or not (entry.get("visible_to", []) as Array).is_empty():
			continue
		var type: String = String(entry["type"])
		if PANEL_TYPES.has(type):
			var k: String = PANEL_TYPES[type]
			expected[k] = int(expected.get(k, 0)) + 1
			expected_seqs.append(int(entry["log_seq"]))
		elif type == Types.LOG_CARD_PLAYED:
			cards_played += 1
	var layer: FeedbackLayer = fb.layer
	var st: Dictionary = fb.bus.stats()
	for k: String in ["damage", "heal", "mana", "potion"]:
		assert_gt(int(expected.get(k, 0)), 0, "la partida produce %s (no pasa en vacío)" % k)
	for k: String in PANEL_TYPES.values():
		assert_eq(int(layer.played.get(k, 0)), int(expected.get(k, 0)), "dibujados = entradas: %s" % k)
		assert_eq(int((st["started"] as Dictionary).get(k, 0)), int(expected.get(k, 0)), "arrancados: %s" % k)
	var drawn: Array = []
	for s: int in layer.played_seqs:
		if expected_seqs.has(s):
			drawn.append(s)
	drawn.sort()
	expected_seqs.sort()
	assert_eq(drawn, expected_seqs, "cada entrada se dibuja una sola vez")
	assert_gt(cards_played, 0)
	var banners: int = int(layer.played.get("card_played", 0))
	assert_eq(banners, int((st["started"] as Dictionary).get("card_played", 0)))
	assert_eq(banners + int((st["dropped"] as Dictionary)["skipped"]), cards_played)
	assert_eq(layer.no_anchor, 0, "todo feedback de panel encuentra su panel")


## Un número y un destello en marcha sobreviven a refresh() y a una
## reconstrucción del abanico; refrescar sin cambios no reconstruye nada.
func test_feedback_survives_refresh() -> void:
	var ls: LocalSession = _session(4)
	var t: TableScreen = _bound(ls)
	await wait_process_frames(3)
	var players: TablePlayers = t.ctx.players
	var panels: Array[PlayerPanel] = players.rival_panels.duplicate()
	var counts: Array[int] = []
	for pp: PlayerPanel in panels:
		counts.append(pp.rebuild_count)
	var fan_rebuilds: int = players.rebuild_count
	var center_rebuilds: int = t.ctx.center.rebuild_count
	var layer: FeedbackLayer = t.feedback().layer
	layer.play(_item("damage", "p2", -2, 9001, {"prevented": 0}))
	layer.play(_item("mana", "p1", 3, 9002))
	assert_eq(layer.visible_texts().size(), 2)
	assert_true(layer.visible_texts().has("▼ -2"))
	assert_true(layer.visible_texts().has("▲ +3 maná"))
	var flashes: Array[ColorRect] = []
	for c: Node in layer.get_children():
		if c is ColorRect and (c as ColorRect).visible:
			flashes.append(c as ColorRect)
	assert_eq(flashes.size(), 1, "un destello (ColorRect) para el daño")
	assert_true(flashes[0].material is ShaderMaterial)
	t.refresh()
	await wait_process_frames(2)
	assert_eq(players.rebuild_count, fan_rebuilds, "mismo abanico: no se reconstruye")
	assert_eq(t.ctx.center.rebuild_count, center_rebuilds, "centro sin cambios: no se reconstruye")
	for i: int in panels.size():
		assert_same(players.rival_panels[i], panels[i])
		assert_eq(panels[i].rebuild_count, counts[i], "panel sin cambios: no se redibuja")
	assert_same(t.panel_for("p2"), panels[0])
	assert_same(t.panel_for("p1"), players.own_panel)
	assert_eq(layer.visible_texts().size(), 2, "el feedback sigue tras refresh()")
	# Forzar reconstrucción (otro jugador mira: cambia el abanico): el feedback
	# está en la capa, no en el panel.
	t.set_view(ls.get_view_for("p3"), "p3")
	await wait_process_frames(1)
	assert_gt(players.rebuild_count, fan_rebuilds, "el abanico se reconstruyó")
	assert_eq(layer.visible_texts().size(), 2, "el feedback sigue tras reconstruir paneles")
	assert_true(flashes[0].visible)
	assert_true(flashes[0].is_inside_tree())
	# Termina tras >= 1 s.
	await wait_seconds(0.9)
	assert_eq(layer.visible_texts().size(), 2, "visible al menos ~1 s")
	await wait_seconds(0.6)
	assert_eq(layer.visible_texts().size(), 0, "termina")


## Un cambio de un jugador solo redibuja su panel.
func test_incremental_only_changed_panel() -> void:
	var ls: LocalSession = _session(4)
	var t: TableScreen = _bound(ls)
	await wait_process_frames(3)
	var panels: Array[PlayerPanel] = t.ctx.players.rival_panels.duplicate()
	var counts: Array[int] = []
	for pp: PlayerPanel in panels:
		counts.append(pp.rebuild_count)
	var v: Dictionary = ls.get_view_for("p1")
	(Types.get_player(v, "p3"))["hp"] = 1
	t.set_view(v, "p1")
	assert_eq(panels[0].rebuild_count, counts[0], "p2 igual")
	assert_eq(panels[1].rebuild_count, counts[1] + 1, "p3 cambia")
	assert_eq(panels[2].rebuild_count, counts[2], "p4 igual")
	assert_same(t.ctx.players.rival_panels[1], panels[1])


## Textos: glifos, maná, "Bloqueado" y aviso "Bruno → Fireball → Ana".
func test_texts_and_banner() -> void:
	var ls: LocalSession = _session(3)
	var t: TableScreen = _bound(ls)
	await wait_process_frames(3)
	var layer: FeedbackLayer = t.feedback().layer
	layer.play(_item("heal", "p3", 1, 1))
	layer.play(_item("damage", "p2", 0, 2, {"prevented": 3}))
	layer.play(_item("mana", "p2", -2, 3))
	var texts: Array[String] = layer.visible_texts()
	assert_true(texts.has("▲ +1"), str(texts))
	assert_true(texts.has("Bloqueado"), str(texts))
	assert_true(texts.has("▼ -2 maná"), str(texts))
	var card: Dictionary = {"log_seq": 4, "rev": 1, "kind": "card_played", "lane": "banner", "target": "",
		"actor": "p2", "amount": -3, "card_id": Types.CARD_FIREBALL, "targets": ["p1"],
		"extra": {"caster": "p2"}, "visible_to": [], "duration_ms": FeedbackMapper.DUR_BANNER_MS}
	layer.play(card)
	assert_true(layer.is_banner_visible())
	assert_eq(layer.banner_text(), "Bruno → Fireball → Ana")
	assert_true(layer.visible_texts().has("▼ -3 maná"), "coste en el panel del que lanza")
	# Sin panel (pid inexistente): no dibuja y no falla.
	layer.play(_item("damage", "p9", -1, 5))
	assert_eq(layer.no_anchor, 1)


## Hot-seat: el bus está bloqueado mientras se ve "Pasa el dispositivo".
func test_pass_screen_blocks_bus() -> void:
	var ls: LocalSession = _session(3, 2)
	var t: TableScreen = _bound(ls)
	await wait_process_frames(2)
	var bus: PresentationBus = t.feedback().bus
	assert_eq(bus.is_blocked(), t._pass_screen.visible)
	# Fin de turno de quien mira -> decide el otro humano -> pantalla de paso.
	var guard: int = 0
	while not t._pass_screen.visible and guard < 40:
		guard += 1
		var d: String = Decision.local_decider(ls.state, ls.get_local_player_ids())
		if d == "":
			if not ls.step_bot():
				break
			continue
		ls.submit_action(Bot.choose_action(ls.get_view_for(d), d, guard, 0)["action"])
	assert_true(t._pass_screen.visible, "se pidió pasar el dispositivo")
	assert_true(bus.is_blocked())
	t._pass_screen._on_pressed()
	assert_false(bus.is_blocked())


## Registro plegado: misma franja que con el log entero; al desplegar, log entero.
func test_collapsed_log_gets_strip_only() -> void:
	var ls: LocalSession = _session(3)
	var t: TableScreen = _bound(ls)
	await wait_process_frames(2)
	for i: int in 30:
		var d: String = Decision.local_decider(ls.state, ["p1"] as Array[String])
		if d != "":
			ls.submit_action(Bot.choose_action(ls.get_view_for(d), d, i, 0)["action"])
		elif not ls.step_bot():
			break
	var log_entries: Array = t.view.get("log", []) as Array
	assert_gt(log_entries.size(), ActionLog.STRIP_LINES)
	var full: ActionLog = ActionLog.new()
	full.set_entries(log_entries, t.ctx.names())
	autofree(full)
	var al: ActionLog = t._log
	assert_eq(al.lines.size(), ActionLog.STRIP_LINES, "plegado: solo la franja")
	assert_eq(al.strip_lines(), full.strip_lines(), "la franja no cambia")
	al.set_expanded(true)
	assert_eq(al.lines.size(), log_entries.size(), "desplegado: log entero")
	assert_eq(al.lines, full.lines)
	al.set_expanded(false)
	assert_eq(al.strip_lines(), full.strip_lines())
