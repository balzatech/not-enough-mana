extends SceneTree
## Captura V2-23: mesa con mano resaltada y ficha de una carta seleccionada (no es un test GUT).
##   godot --path . -s tests/ui/capture_hand_info.gd -- <carta> <salida.png> [ancho=720] [alto=1280]
const H = preload("res://tests/fixtures/engine_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_run.call_deferred(a[0] if a.size() > 0 else "ice_bolt", a[1] if a.size() > 1 else "/tmp/hand_info.png",
		int(a[2]) if a.size() > 2 else 720, int(a[3]) if a.size() > 3 else 1280)


func _run(card: String, out: String, w: int, h: int) -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var s: Dictionary = H.game(4, {}, 7, [40, 30, 20, 25])
	H.set_hand(s, "p1", ["fire_arrow", "fireball", "ice_bolt", "heal", "magic_shield", "elixir_transmutation"])
	H.set_mana(s, "p1", 1)
	H.force_turn(s, "p1")
	s["pending"] = []
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
	for i: int in 8:
		await process_frame
	for c: Variant in H.hand(s, "p1"):
		if String((c as Dictionary)["card_id"]) == card:
			t._on_hand_tapped({"iid": int((c as Dictionary)["iid"])})
	for i: int in 8:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	quit()
