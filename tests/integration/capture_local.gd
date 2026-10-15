extends SceneTree
## Capturas de la mesa con una LocalSession real (revisión visual, no es test).
##   godot --path . -s tests/integration/capture_local.gd -- <caso> <salida.png> [semilla]
## caso: start | midgame | reaction | hotseat | gameover | payment

const H = preload("res://tests/fixtures/engine_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "start"
	var out: String = args[1] if args.size() > 1 else "/tmp/capture_local.png"
	var sd: int = int(args[2]) if args.size() > 2 else 11
	_run.call_deferred(which, out, sd)


func _setup(humans: int) -> Dictionary:
	var players: Array = []
	var names: Array[String] = ["Ana", "Bruno", "Cira", "Dario"]
	for i: int in 3:
		players.append({"name": names[i], "age": 30 + i * 5, "birth_month": i + 2, "is_bot": i >= humans})
	return {"players": players, "config": {"potion_limit_enabled": true, "potion_limit": 10, "potion_mana": 3,
		"include_curse_of_rules": true, "reaction_timeout_local_ms": 15000, "mode": "local"}}


func _run(which: String, out: String, sd: int) -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(540, 960)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	vp.add_child(t)
	var ls: LocalSession
	if which == "reaction" or which == "payment":
		var players: Array = [Types.make_player("p1", "Ana", 40, 1, false),
			Types.make_player("p2", "Bruno", 30, 2, true), Types.make_player("p3", "Cira", 20, 3, true)]
		var s: Dictionary = Game.new_game(players, {"reaction_timeout_local_ms": 15000}, sd)
		H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD, Types.CARD_FIREBALL, Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
		H.set_hand(s, "p2", [Types.CARD_ICE_BOLT])
		H.set_mana(s, "p1", 4)
		H.set_mana(s, "p2", 5)
		H.force_turn(s, "p1" if which == "payment" else "p2")
		ls = LocalSession.new()
		ls.start(s, sd)
	else:
		ls = LocalSession.create(_setup(3 if which == "hotseat" else 1), sd)
	ls.auto_run_bots = false
	t.bind_session(ls)
	for i: int in 10:
		await process_frame
	match which:
		"midgame", "gameover":
			var limit: int = 60 if which == "midgame" else 5000
			for i: int in limit:
				if String(ls.state["status"]) != Types.STATUS_PLAYING:
					break
				var d: String = Decision.local_decider(ls.state, ls.get_local_player_ids())
				if d != "":
					var a: Dictionary = Bot.choose_action(ls.get_view_for(d), d, sd + i, 0)["action"]
					if not a.is_empty():
						ls.submit_action(a)
						continue
				ls.run_bots(1)
			t._notice_overlay.visible = false
		"reaction":
			var bolt: int = int((H.hand(ls.state, "p2")[0] as Dictionary)["iid"])
			ls.submit_action(Types.make_action_play_card("p2", bolt, ["p1"]))
			t._notice_overlay.visible = false
		"payment":
			t._notice_overlay.visible = false
			var fb: int = -1
			for c: Variant in H.hand(ls.state, "p1"):
				if String((c as Dictionary)["card_id"]) == Types.CARD_FIREBALL:
					fb = int((c as Dictionary)["iid"])
			t._on_hand_tapped({"iid": fb})
			t._play_btn.pressed.emit()
			t._on_panel_tapped("p2")
	for i: int in 20:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(out)
	print("captura: %s" % out)
	quit()
