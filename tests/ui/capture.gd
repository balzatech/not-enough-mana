extends SceneTree
## Captura de pantallas para revisión visual (no es un test GUT).
##
## Uso (necesita pantalla/GPU, no --headless):
##   godot --path . -s tests/ui/capture.gd -- <escena> <ancho> <alto> <salida.png> [n_jugadores] [extra]
## escena: table | reaction | pass | main_menu | local_setup | lobby | settings | prompt
## El SubViewport usa tamaño base 1080x1920; si <ancho>x<alto> es menor, se escala
## (igual que stretch=canvas_items en un móvil de 720x1280).

const BASE: Vector2i = Vector2i(1080, 1920)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "table"
	var w: int = int(args[1]) if args.size() > 1 else 1080
	var h: int = int(args[2]) if args.size() > 2 else 1920
	var out: String = args[3] if args.size() > 3 else "/tmp/capture.png"
	var n: int = int(args[4]) if args.size() > 4 else 4
	var extra: String = args[5] if args.size() > 5 else ""
	_run.call_deferred(which, w, h, out, n, extra)


func _run(which: String, w: int, h: int, out: String, n: int, extra: String) -> void:
	FakeState.install_defs()
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var node: Control = _make(which, n)
	vp.add_child(node)
	for i: int in 12:
		await process_frame
	await _after(which, node, extra)
	for i: int in 6:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(out)
	print("captura: %s (%dx%d)" % [out, img.get_width(), img.get_height()])
	quit()


func _make(which: String, n: int) -> Control:
	match which:
		"table", "reaction", "pass", "prompt":
			var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
			var st: Dictionary = FakeState.make_state(n)
			if which == "reaction":
				var deadline: int = int(Time.get_unix_time_from_system() * 1000.0) + 9000
				st = FakeState.with_reaction(st, deadline)
				var s0: Dictionary = st["reaction"]
				(s0["awaiting"] as Array).clear()
				(s0["awaiting"] as Array).append("p1")
			if which == "prompt":
				st["pending"] = [Types.make_prompt(5, "p1", Types.PROMPT_MANA_SHORTFALL, {"missing": 2})]
			var fs: FakeSession = FakeSession.create(st, ["p1"] as Array[String])
			t.set_meta("fs", fs)
			return t
		"main_menu":
			return (load("res://src/ui/screens/main_menu.tscn") as PackedScene).instantiate()
		"local_setup":
			return (load("res://src/ui/screens/local_setup.tscn") as PackedScene).instantiate()
		"lobby":
			return (load("res://src/ui/screens/lobby.tscn") as PackedScene).instantiate()
		_:
			return (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()


func _after(which: String, node: Control, extra: String) -> void:
	if node is TableScreen:
		var t: TableScreen = node
		var fs: FakeSession = t.get_meta("fs")
		t.bind_session(fs)
		await process_frame
		if which == "pass":
			t._pass_screen.show_for("Brisa")
		if extra == "select":
			t._on_hand_tapped(fs.state["players"][0]["hand"][1])
		if extra == "log":
			t._log.set_expanded(true)
		if extra == "zoom":
			var c: Dictionary = fs.state["players"][0]["hand"][0]
			t._show_zoom(c, UiUtil.card_def(String(c["card_id"])))
		if extra == "target":
			t.begin_play(int(fs.state["players"][0]["hand"][0]["iid"]), false)
		for i: int in 8:
			await process_frame
