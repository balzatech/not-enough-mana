extends SceneTree
## Capturas de legibilidad móvil (V2-33) con motor y LocalSession reales. Revisión visual, no es un test GUT.
## Uso (necesita pantalla, no --headless):
##   godot --path . -s tests/ui/capture_legibility.gd -- <caso> <salida.png> [ancho=1080] [alto=1920] [jugadores=6]
## caso: mesa | eliminado | mana-focus | elixir | magic-cap | mana-insuficiente | descarte | reaccion
## Imprime los rects del panel propio, la fila de acciones, Beber poción y el diálogo.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)
const NAMES: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Elena", "Fabio"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "mesa"
	var out: String = args[1] if args.size() > 1 else "/tmp/capture_legibility.png"
	var w: int = int(args[2]) if args.size() > 2 else 1080
	var h: int = int(args[3]) if args.size() > 3 else 1920
	var n: int = int(args[4]) if args.size() > 4 else 6
	_run.call_deferred(which, out, w, h, n)


func _players(n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i * 5, i + 1, i > 0))
	return out


func _state(n: int, turn: String = "p1") -> Dictionary:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var s: Dictionary = Game.new_game(_players(n), {"reaction_timeout_local_ms": 15000}, 11)
	H.force_turn(s, turn)
	s["pending"] = []
	return s


func _equip(s: Dictionary, pid: String, card_id: String) -> Dictionary:
	H.force_turn(s, pid)
	var iid: int = X.give(s, pid, card_id)
	var pay: Array = X.pay_for(s, pid, card_id)
	var p: Dictionary = H.player(s, pid)
	var before: int = int(p["mana"])
	p["mana"] = before + Damage.card_cost(s, pid, CardCatalog.get_def(card_id))
	var r: Dictionary = Game.reduce(s, Types.make_action_play_card(pid, iid, [], pay))
	assert(String(r["error"]) == "", "equip: " + String(r["error"]))
	var ns: Dictionary = H.settle(r["state"])
	H.player(ns, pid)["mana"] = before
	return ns


func _build(which: String, n: int) -> Dictionary:
	var s: Dictionary = _state(n)
	match which:
		"eliminado":
			if n >= 3:
				Damage.eliminate(s, "p3", "hp", [])
				H.player(s, "p3")["hp"] = 0
			var f: Dictionary = H.player(s, "p2")["flags"] as Dictionary
			f["frozen"] = 1
			f["blinded"] = true
			f["force_field"] = Types.CARD_FIREBALL
			s = _equip(s, "p2", Types.CARD_MAGIC_CAP)
			H.force_turn(s, "p1")
			H.player(s, "p1")["potions"] = 8
		"mana-insuficiente":
			H.set_mana(s, "p1", 0)
			(s["pending"] as Array).append(Types.make_prompt(Types.next_seq(s), "p1",
				Types.PROMPT_MANA_SHORTFALL, {"missing": 2}, Types.CARD_FIREBALL))
		"magic-cap":
			s = _equip(s, "p1", Types.CARD_MAGIC_CAP)
			H.force_turn(s, "p2")
			X.spell_damage(s, "p2", "p1", 3, Types.ELEMENT_FIRE)
		"mana-focus":
			X.event(s, Types.CARD_MANA_FOCUS)
			H.set_mana(s, "p1", 5)
			X.spell_damage(s, "p2", "p1", 3, Types.ELEMENT_FIRE)
		"elixir":
			H.player(s, "p1")["hp"] = 6
			H.set_mana(s, "p1", 7)
			X.event(s, Types.CARD_ELIXIR_TRANSMUTATION, "p2")
		"descarte":
			Damage.forced_discard(s, "p1", 2, [], Types.CARD_ICY_GRASP)
		"reaccion":
			H.force_turn(s, "p2")
			H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD, Types.CARD_FIREBALL, Types.CARD_HEAL])
			H.set_hand(s, "p2", [Types.CARD_ICE_BOLT])
			H.set_mana(s, "p2", 5)
			H.player(s, "p1")["potions"] = 8
	return s


static func _r(c: Control) -> String:
	if c == null or not c.is_visible_in_tree():
		return "-"
	var r: Rect2 = c.get_global_rect()
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]


func _run(which: String, out: String, w: int, h: int, n: int) -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	vp.add_child(t)
	var s: Dictionary = _build(which, n)
	var ls: LocalSession = LocalSession.new()
	ls.start(s, 11)
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
	elif which == "mesa" or which == "eliminado":
		var hand: Array = H.hand(ls.state, "p1")
		if not hand.is_empty():
			t._on_hand_tapped({"iid": int((hand[0] as Dictionary)["iid"])})
	for i: int in 25:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(out)
	var c: TableContext = t.ctx
	print("captura: %s (%dx%d) n=%d" % [out, img.get_width(), img.get_height(), n])
	print("  own=%s actions=%s drink=%s mode=%s dialog=%s hand=%s fan=%s center=%s" % [_r(c.players.own_panel),
		_r(c.actions.action_row), _r(c.actions.drink_btn), _r(c.mode_bar.bar), _r(c.dialogs.dialog),
		_r(c.hand.hand_view), _r(c.players.rival_fan), _r(c.center.center)])
	for pp: PlayerPanel in c.players.rival_panels:
		print("  rival %s %s icons=%s" % [pp.player_id, _r(pp), str(pp.status_icons())])
	quit()
