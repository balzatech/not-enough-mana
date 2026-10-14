extends SceneTree
## Capturas V2-36 (defectos finales de v0.2) con 6 jugadores y LocalSession real. Revisión visual, no es un test.
## Uso (necesita pantalla, no --headless):
##   godot --path . -s tests/ui/capture_defectos_finales.gd -- <caso> <salida.png> [ancho=1080] [alto=1920] [jugadores=6]
## caso: reaccion | descarte | registro | registro-abierto | ajustes

const H = preload("res://tests/fixtures/engine_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)
const NAMES: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Elena", "Fabio"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_run.call_deferred(args[0] if args.size() > 0 else "reaccion", args[1] if args.size() > 1 else "/tmp/df.png",
		int(args[2]) if args.size() > 2 else 1080, int(args[3]) if args.size() > 3 else 1920,
		int(args[4]) if args.size() > 4 else 6)


func _state(which: String, n: int) -> Dictionary:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i * 5, i + 1, i > 0))
	var s: Dictionary = Game.new_game(players, {"reaction_timeout_local_ms": 15000}, 21)
	H.force_turn(s, "p1")
	s["pending"] = []
	match which:
		"descarte":
			Damage.forced_discard(s, "p1", 2, [], Types.CARD_ICY_GRASP)
		"reaccion":
			H.force_turn(s, "p2")
			H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD, Types.CARD_FIREBALL])
			H.set_hand(s, "p2", [Types.CARD_ICE_BOLT])
			H.set_mana(s, "p2", 5)
			H.player(s, "p1")["potions"] = 9
	return s


func _run(which: String, out: String, w: int, h: int, n: int) -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	if which == "ajustes":
		var st: Settings = (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()
		st.auto_navigate = false
		vp.add_child(st)
	else:
		var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
		t.demo_when_empty = false
		vp.add_child(t)
		var ls: LocalSession = LocalSession.new()
		ls.start(_state(which, n), 21)
		ls.auto_run_bots = false
		t.bind_session(ls)
		for i: int in 10:
			await process_frame
		t._notice_overlay.visible = false
		for i: int in 10:
			await process_frame
		if which == "reaccion":
			var bolt: int = int((H.hand(ls.state, "p2")[0] as Dictionary)["iid"])
			ls.submit_action(Types.make_action_play_card("p2", bolt, ["p1"]))
		if which == "registro-abierto":
			t._log.set_expanded(true)
	for i: int in 30:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(out)
	print("captura: %s (%dx%d)" % [out, img.get_width(), img.get_height()])
	quit()
