extends SceneTree
## Captura V2-29 (no es un test GUT):
##   godot --path . -s tests/ui/capture_context_risk.gd -- <potion|against|pass> <salida.png> [ancho=720] [alto=1280]
const H = preload("res://tests/fixtures/engine_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_run.call_deferred(a[0] if a.size() > 0 else "potion", a[1] if a.size() > 1 else "/tmp/v2_29.png",
		int(a[2]) if a.size() > 2 else 720, int(a[3]) if a.size() > 3 else 1280)


func _run(mode: String, out: String, w: int, h: int) -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var s: Dictionary = H.game(3, {}, 7, [40, 30, 20])
	H.set_hand(s, "p1", ["fire_arrow", "fireball", "magic_shield", "heal"])
	H.force_turn(s, "p1")
	s["pending"] = []
	Types.get_player(s, "p1")["potions"] = 8
	if mode == "against":
		var spell: Dictionary = Types.make_spell({"iid": 900, "card_id": Types.CARD_FIREBALL}, "p2", ["p1"])
		s["reaction"] = Types.make_reaction(spell, ["p1"])
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.size_2d_override = BASE
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	vp.add_child(t)
	t.set_view(Types.view_for(s, "p1"), "p1")
	if mode == "pass":
		t._pass_screen.show_for("Cira", Strings.PASS_REASON_REACTION)
	for i: int in 10:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	quit()
