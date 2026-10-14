extends SceneTree
## Capturas v0.2 (V2-03) con motor y LocalSession reales. Revisión visual, no es un test GUT.
## Reutiliza el patrón de tests/ui/capture.gd (SubViewport escalado desde 1080x1920) y de
## tests/integration/capture_local.gd (LocalSession real).
## Uso (necesita pantalla, no --headless):
##   godot --path . -s tests/ui/capture_v02.gd -- <caso> <salida.png> [ancho=1080] [alto=1920] [semilla=11]
## caso: mana-insuficiente | magic-cap | mana-focus | elixir | descarte | zoom | mesa-6j
##       | base-inicio | base-reaccion | base-pago

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)
const NAMES: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Elena", "Fabio"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "zoom"
	var out: String = args[1] if args.size() > 1 else "/tmp/capture_v02.png"
	var w: int = int(args[2]) if args.size() > 2 else 1080
	var h: int = int(args[3]) if args.size() > 3 else 1920
	var sd: int = int(args[4]) if args.size() > 4 else 11
	_run.call_deferred(which, out, w, h, sd)


func _players(n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i * 5, i + 1, i > 0))
	return out


## Estado real de n magos (p1 = humano Ana), turno de `turn`, sin prompts ni evento.
func _state(n: int, sd: int, turn: String = "p1") -> Dictionary:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var s: Dictionary = Game.new_game(_players(n), {"reaction_timeout_local_ms": 15000}, sd)
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


func _build(which: String, sd: int) -> Dictionary:
	var s: Dictionary
	match which:
		"mana-insuficiente":
			s = _state(4, sd)
			H.set_mana(s, "p1", 0)
			(s["pending"] as Array).append(Types.make_prompt(Types.next_seq(s), "p1",
				Types.PROMPT_MANA_SHORTFALL, {"missing": 2}, Types.CARD_FIREBALL))
		"magic-cap":
			s = _equip(_state(4, sd), "p1", Types.CARD_MAGIC_CAP)
			H.force_turn(s, "p2")
			X.spell_damage(s, "p2", "p1", 3, Types.ELEMENT_FIRE)
		"mana-focus":
			s = _state(4, sd)
			X.event(s, Types.CARD_MANA_FOCUS)
			H.set_mana(s, "p1", 5)
			X.spell_damage(s, "p2", "p1", 3, Types.ELEMENT_FIRE)
		"elixir":
			s = _state(4, sd)
			H.player(s, "p1")["hp"] = 6
			H.set_mana(s, "p1", 7)
			X.event(s, Types.CARD_ELIXIR_TRANSMUTATION, "p2")
		"descarte":
			s = _state(4, sd)
			Damage.forced_discard(s, "p1", 2, [], Types.CARD_ICY_GRASP)
		"zoom", "base-inicio":
			s = _state(4, sd)
		"mesa-6j":
			s = _state(6, sd)
		"base-reaccion", "base-pago":
			s = _state(3, sd, "p1" if which == "base-pago" else "p2")
			H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD, Types.CARD_FIREBALL, Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
			H.set_hand(s, "p2", [Types.CARD_ICE_BOLT])
			H.set_mana(s, "p1", 4)
			H.set_mana(s, "p2", 5)
	return s


func _run(which: String, out: String, w: int, h: int, sd: int) -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	vp.add_child(t)
	var s: Dictionary = _build(which, sd)
	var ls: LocalSession = LocalSession.new()
	ls.start(s, sd)
	ls.auto_run_bots = false
	t.bind_session(ls)
	for i: int in 10:
		await process_frame
	t._notice_overlay.visible = false
	for i: int in 20:
		await process_frame
	match which:
		"zoom":
			var c: Dictionary = H.hand(ls.state, "p1")[0]
			t._show_zoom(c, UiUtil.card_def(String(c["card_id"])))
		"base-reaccion":
			var bolt: int = int((H.hand(ls.state, "p2")[0] as Dictionary)["iid"])
			ls.submit_action(Types.make_action_play_card("p2", bolt, ["p1"]))
		"base-pago":
			var fb: int = -1
			for c: Variant in H.hand(ls.state, "p1"):
				if String((c as Dictionary)["card_id"]) == Types.CARD_FIREBALL:
					fb = int((c as Dictionary)["iid"])
			t._on_hand_tapped({"iid": fb})
			t._play_btn.pressed.emit()
			t._on_panel_tapped("p2")
	for i: int in 25:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(out)
	print("captura: %s (%dx%d) pending=%d" % [out, img.get_width(), img.get_height(), (ls.state["pending"] as Array).size()])
	quit()
