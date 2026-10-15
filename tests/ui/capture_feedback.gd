extends SceneTree
## Captura del feedback de la mesa (V2-22): número flotante, destello y aviso de
## carta jugada, con motor y LocalSession reales. Revisión visual, no es un test GUT.
## Uso (necesita pantalla, no --headless):
##   godot --path . -s tests/ui/capture_feedback.gd -- <salida.png> [jugadores=4] [ancho=1080] [alto=1920] [semilla=11]
## Juega (p1 con el bot) hasta el primer daño y captura ~0,35 s después.

const BASE: Vector2i = Vector2i(1080, 1920)
const NAMES: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Eva", "Fede"]

var _hit: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/capture_feedback.png"
	var np: int = int(args[1]) if args.size() > 1 else 4
	var w: int = int(args[2]) if args.size() > 2 else 1080
	var h: int = int(args[3]) if args.size() > 3 else 1920
	var sd: int = int(args[4]) if args.size() > 4 else 11
	_run.call_deferred(out, np, w, h, sd)


func _run(out: String, np: int, w: int, h: int, sd: int) -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var players: Array = []
	for i: int in np:
		players.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i * 5, i + 1, i > 0))
	var s: Dictionary = Game.new_game(players, {"reaction_timeout_local_ms": 15000}, sd)
	var ls: LocalSession = LocalSession.new()
	ls.auto_run_bots = false
	ls.start(s, sd)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	vp.add_child(t)
	t.bind_session(ls)
	for i: int in 5:
		await process_frame
	var bus: PresentationBus = t.feedback().bus
	bus.feedback_started.connect(func(it: Dictionary) -> void:
		if String(it["kind"]) == FeedbackMapper.FB_DAMAGE and int(it["amount"]) < 0:
			_hit = true)
	var ids: Array[String] = ["p1"]
	for i: int in 400:
		if _hit or String(ls.state["status"]) != Types.STATUS_PLAYING:
			break
		var d: String = Decision.local_decider(ls.state, ids)
		if d != "":
			var a: Dictionary = Bot.choose_action(ls.get_view_for(d), d, sd + i, 0)["action"]
			if a.is_empty():
				break
			ls.submit_action(a)
		elif not ls.step_bot():
			break
		# Deja correr el bus unos fotogramas (como entre acciones de bot).
		for f: int in 4:
			await process_frame
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 350:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(out)
	print("CAPTURE %s hit=%s texts=%s banner=%s" % [out, _hit, t.feedback().layer.visible_texts(),
		t.feedback().layer.banner_text()])
	quit()
